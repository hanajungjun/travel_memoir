import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/services/travel_day_service.dart';
import 'package:travel_memoir/services/gemini_service.dart';
import 'package:travel_memoir/services/image_upload_service.dart';
import 'package:travel_memoir/services/travel_highlight_service.dart';

import 'package:travel_memoir/core/constants/korea/sgg_code_map.dart';
import 'package:travel_memoir/storage_paths.dart';

class TravelCompleteService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<void> tryCompleteTravel({
    required String travelId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    debugPrint('==============================');
    debugPrint('🔥 [COMPLETE] tryCompleteTravel START');
    debugPrint('🔥 travelId=$travelId');
    debugPrint('==============================');

    // 0️⃣ 유저 확인
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final userId = user.id;

    // 1️⃣ 여행 조회
    final travel = await _supabase
        .from('travels')
        .select()
        .eq('id', travelId)
        .single();

    if (travel['is_completed'] == true) return;

    // 2️⃣ 일기 개수 체크
    final writtenDays = await TravelDayService.getWrittenDayCount(
      travelId: travelId,
    );
    final totalDays = endDate.difference(startDate).inDays + 1;
    if (writtenDays < totalDays) return;

    // 3️⃣ 여행 완료 처리
    await _supabase
        .from('travels')
        .update({
          'is_completed': true,
          'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', travelId);

    // 4️⃣ 국내 지역 upsert (🔥 완료 시 → is_completed = true 로 색 전환)
    if (travel['travel_type'] == 'domestic') {
      final String? regionId = travel['region_id'];
      if (regionId != null) {
        final code = SggCodeMap.fromRegionId(regionId);

        await _supabase.from('domestic_travel_regions').upsert({
          'travel_id': travelId,
          'user_id': userId,
          'region_id': regionId,
          'map_region_id': regionId,
          'map_region_type': code.type,
          'sido_cd': code.sidoCd,
          'sgg_cd': code.sggCd,
          'is_completed': true, // ✅ 완료 → 색 변경용
        }, onConflict: 'user_id,region_id');
      }
    }

    final gemini = GeminiService();
    // 🌐 한국어 설정 여부 확인
    final bool isKo = PlatformDispatcher.instance.locale.languageCode == 'ko';

    final String placeName =
        (travel['travel_type'] == 'domestic'
                ? travel['region_name']
                : (isKo
                      ? travel['country_name_ko']
                      : travel['country_name_en']))
            ?.toString() ??
        '여행';

    // 5️⃣ cover 이미지
    try {
      final row = await _supabase
          .from('ai_cover_map_prompts')
          .select('content')
          .eq('type', 'cover')
          .eq('is_active', true)
          .maybeSingle();

      if (row?['content'] != null) {
        final bytes = await gemini.generateImage(
          finalPrompt: '${row!['content']}\nPlace: $placeName',
        );
        if (bytes.isNotEmpty) {
          await ImageUploadService.uploadTravelCover(
            userId: userId,
            travelId: travelId,
            imageBytes: bytes,
          );
        }
      }
    } catch (_) {}

    // 6️⃣ map 이미지
    try {
      final row = await _supabase
          .from('ai_cover_map_prompts')
          .select('content')
          .eq('type', 'map')
          .eq('is_active', true)
          .maybeSingle();

      if (row?['content'] != null) {
        final bytes = await gemini.generateImage(
          finalPrompt: '${row!['content']}\nPlace: $placeName',
        );
        if (bytes.isNotEmpty) {
          await ImageUploadService.uploadTravelMap(
            userId: userId,
            travelId: travelId,
            imageBytes: bytes,
          );
        }
      }
    } catch (_) {}

    // 7️⃣ cover/map URL 저장
    final coverPath = StoragePaths.travelCover(userId, travelId);
    final mapPath = StoragePaths.travelMap(userId, travelId);

    final coverUrl = _supabase.storage
        .from('travel_images')
        .getPublicUrl(coverPath);
    final mapUrl = _supabase.storage
        .from('travel_images')
        .getPublicUrl(mapPath);

    await _supabase
        .from('travels')
        .update({'cover_image_url': coverUrl, 'map_image_url': mapUrl})
        .eq('id', travelId);

    // 8️⃣ 여행 요약
    try {
      final highlight =
          await TravelHighlightService.generateHighlight(
            travelId: travelId,
            placeName: placeName,
          ) ??
          '';
      if (highlight.isNotEmpty) {
        await _supabase
            .from('travels')
            .update({'ai_cover_summary': highlight})
            .eq('id', travelId);
      }
    } catch (_) {}

    // 9️⃣ 🔥 day 이미지 생성 (여행 완료 시) - 주석 그대로 유지
    /*
    try {
      final days = await _supabase
          .from('travel_days')
          .select('date, ai_summary, ai_style')
          .eq('travel_id', travelId)
          .order('date');

      for (final d in days) {
        final dateRaw = d['date'];
        if (dateRaw == null) continue;

        final summary = (d['ai_summary'] ?? '').toString().trim();
        if (summary.isEmpty) continue;

        final style = (d['ai_stylea'] ?? 'default').toString();

        final bytes = await gemini.generateImage(
          finalPrompt:
              '''
여행 그림일기 한 장
날짜: $dateRaw
장소: $placeName
내용: $summary
스타일: $style
따뜻한 감성, 그림일기, 정사각형
''',
        );

        if (bytes.isEmpty) continue;

        final path = StoragePaths.travelDayImage(
          userId,
          travelId,
          dateRaw.toString(),
        );

        await _supabase.storage
            .from('travel_images')
            .uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );

        final imageUrl = _supabase.storage
            .from('travel_images')
            .getPublicUrl(path);

        await _supabase
            .from('travel_days')
            .update({'image_url': imageUrl})
            .eq('travel_id', travelId)
            .eq('date', dateRaw);
      }
    } catch (_) {}
    */

    debugPrint('✅ [COMPLETE] tryCompleteTravel END');
  }
}
