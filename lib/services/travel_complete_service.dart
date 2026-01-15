import 'dart:ui';
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

    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final userId = user.id;

    // 1️⃣ 여행 조회 (region_id 포함)
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

    // 🎯 [수정] 국내 여행인 경우 region_id를 region_key로 활용
    final String? regionId = travel['region_id'];

    // 3️⃣ 여행 완료 처리 (region_key도 함께 업데이트)
    await _supabase
        .from('travels')
        .update({
          'is_completed': true,
          'completed_at': DateTime.now().toIso8601String(),
          'region_key': regionId, // ✅ DB에 region_key 저장
        })
        .eq('id', travelId);

    // 4️⃣ 국내 지역 upsert
    if (travel['travel_type'] == 'domestic' && regionId != null) {
      final code = SggCodeMap.fromRegionId(regionId);
      await _supabase.from('domestic_travel_regions').upsert({
        'travel_id': travelId,
        'user_id': userId,
        'region_id': regionId,
        'map_region_id': regionId,
        'map_region_type': code.type,
        'sido_cd': code.sidoCd,
        'sgg_cd': code.sggCd,
        'is_completed': true,
      }, onConflict: 'user_id,region_id');
    }

    final gemini = GeminiService();
    final bool isKo = PlatformDispatcher.instance.locale.languageCode == 'ko';

    final String placeName =
        (travel['travel_type'] == 'domestic'
                ? travel['region_name']
                : (isKo
                      ? travel['country_name_ko']
                      : travel['country_name_en']))
            ?.toString() ??
        '여행';

    // 5️⃣ cover 이미지 (이건 AI가 여행 요약을 그려주는 거라 유지합니다)
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

    // 🚫 [삭제] 6️⃣ map 이미지 생성 로직 (이제 AI 호출 안 함!)
    // -------------------------------------------------------
    // 더 이상 Gemini에게 지도를 그리라고 하지 않고,
    // 우리가 map_images 버킷에 올린 걸 씁니다.
    // -------------------------------------------------------

    // 7️⃣ cover URL 업데이트 (map_url은 TravelListService에서 동적 처리하므로 생략 가능하나 명시적 업데이트)
    final coverPath = StoragePaths.travelCover(userId, travelId);
    final coverUrl = _supabase.storage
        .from('travel_images')
        .getPublicUrl(coverPath);

    // ✅ [수정] map_url은 국내 여행이면 map_images 버킷 경로로 지정
    String mapUrl;
    if (regionId != null && travel['travel_type'] == 'domestic') {
      mapUrl = _supabase.storage
          .from('map_images')
          .getPublicUrl('$regionId.png');
    } else {
      mapUrl = _supabase.storage
          .from('travel_images')
          .getPublicUrl('${StoragePaths.travelRoot(userId, travelId)}/map.png');
    }

    await _supabase
        .from('travels')
        .update({
          'cover_image_url': coverUrl,
          'map_image_url': mapUrl, // ✅ 완성된 URL 저장
        })
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

    debugPrint('✅ [COMPLETE] tryCompleteTravel END');
  }
}
