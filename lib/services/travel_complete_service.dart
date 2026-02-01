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
    debugPrint('==================================================');
    debugPrint('🚀 [COMPLETE_SERVICE] START travelId=$travelId');

    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint('⛔️ [COMPLETE_SERVICE] user == null');
      return;
    }
    final userId = user.id;

    try {
      debugPrint('➡️ [COMPLETE_SERVICE] fetch travel');
      final travel = await _supabase
          .from('travels')
          .select()
          .eq('id', travelId)
          .single();

      debugPrint('➡️ 짜증나네is_completed =${travel['is_completed']}');
      debugPrint('➡️ 짜증나네cover_image_url =${travel['cover_image_url']}');

      // ✅ [여기입니다!] 기존의 if문을 아래 내용으로 교체하세요.
      // 이미 완료되었더라도 '커버 이미지'가 없으면(null) 로직을 통과시킵니다.
      if (travel['is_completed'] == true && travel['cover_image_url'] != null) {
        debugPrint('⛔️ [COMPLETE_SERVICE] 이미 완료되었고 커버도 있습니다 → 리턴');
        return;
      }

      debugPrint(
        '➡️ [COMPLETE_SERVICE] travel fetched is_completed=${travel['is_completed']}',
      );

      if (travel['is_completed'] == true) {
        debugPrint('⛔️ [COMPLETE_SERVICE] already completed → return');
        return;
      }

      debugPrint('➡️ [COMPLETE_SERVICE] count written days');
      final writtenDays = await TravelDayService.getWrittenDayCount(
        travelId: travelId,
      );

      // 🔥 의심 지점 수정: 날짜만 기준으로 계산
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      final totalDays = end.difference(start).inDays + 1;

      debugPrint(
        '🧾 [COMPLETE_SERVICE] writtenDays=$writtenDays / totalDays=$totalDays',
      );

      if (writtenDays < totalDays) {
        debugPrint('⛔️ [COMPLETE_SERVICE] not enough written days → return');
        return;
      }

      final String travelType = travel['travel_type'] ?? 'domestic';
      final String? regionId = travel['region_id'];
      final bool isKo = PlatformDispatcher.instance.locale.languageCode == 'ko';

      debugPrint(
        '➡️ [COMPLETE_SERVICE] travelType=$travelType regionId=$regionId',
      );

      // 1️⃣ 여행 완료 처리
      debugPrint('➡️ [COMPLETE_SERVICE] update travel completed');
      await _supabase
          .from('travels')
          .update({
            'is_completed': true,
            'completed_at': DateTime.now().toIso8601String(),
            if (travelType == 'domestic' && regionId != null)
              'region_key': regionId,
          })
          .eq('id', travelId);

      // 2️⃣ 국내 지역 upsert
      if (travelType == 'domestic' && regionId != null) {
        debugPrint('➡️ [COMPLETE_SERVICE] upsert domestic region');
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

      // 2️⃣-1️⃣ 해외 방문 국가 스티커 upsert (이미지 없음 → UI에서 도장 준비중)
      if (travelType != 'domestic') {
        final String? countryCode = travel['country_code']; // ISO_A2
        final String? countryName = isKo
            ? travel['country_name_ko']
            : travel['country_name_en'];

        debugPrint(
          '➡️ [COMPLETE_SERVICE] overseas countryCode=$countryCode countryName=$countryName',
        );

        if (countryCode != null && countryName != null) {
          await _supabase.rpc(
            'upsert_visited_country',
            params: {
              'p_user_id': userId,
              'p_country_code': countryCode,
              'p_country_name': countryName,
            },
          );
          debugPrint('✅ [COMPLETE_SERVICE] visited_countries upsert done');
        } else {
          debugPrint('⛔️ [COMPLETE_SERVICE] countryCode/name null');
        }
      }

      final String placeName =
          (travelType == 'domestic'
                  ? travel['region_name']
                  : (isKo
                        ? travel['country_name_ko']
                        : travel['country_name_en']))
              ?.toString() ??
          '여행';

      // 3️⃣ AI 커버 생성 + 업로드
      debugPrint('➡️ [COMPLETE_SERVICE] generate AI cover');
      try {
        final promptRow = await _supabase
            .from('ai_cover_map_prompts')
            .select('content')
            .eq('type', 'cover')
            .eq('is_active', true)
            .maybeSingle();

        debugPrint(
          '➡️ [COMPLETE_SERVICE] promptRow exists=${promptRow != null}',
        );

        if (promptRow?['content'] != null) {
          final bytes = await GeminiService().generateImage(
            finalPrompt: '${promptRow!['content']}\nPlace: $placeName',
          );
          debugPrint(
            '➡️ [COMPLETE_SERVICE] cover bytes length=${bytes.length}',
          );

          if (bytes.isNotEmpty) {
            await ImageUploadService.uploadTravelCover(
              userId: userId,
              travelId: travelId,
              imageBytes: bytes,
            );
            debugPrint('✅ [COMPLETE_SERVICE] cover uploaded');
          }
        }
      } catch (e) {
        debugPrint('❌ [COMPLETE_SERVICE] cover error $e');
      }

      // 4️⃣ path 저장
      debugPrint('➡️ [COMPLETE_SERVICE] update cover/map path');
      final coverPath = StoragePaths.travelCoverPath(userId, travelId);
      final Map<String, dynamic> finalUpdate = {'cover_image_url': coverPath};

      if (travelType == 'domestic' && regionId != null) {
        finalUpdate['map_image_url'] = '$regionId.png';
      }

      // 5️⃣ AI 요약
      debugPrint('➡️ [COMPLETE_SERVICE] generate summary');
      try {
        final summary = await TravelHighlightService.generateHighlight(
          travelId: travelId,
          placeName: placeName,
        );
        if (summary != null) {
          finalUpdate['ai_cover_summary'] = summary;
          debugPrint('✅ [COMPLETE_SERVICE] summary generated');
        }
      } catch (e) {
        debugPrint('❌ [COMPLETE_SERVICE] summary error $e');
      }

      await _supabase.from('travels').update(finalUpdate).eq('id', travelId);
      debugPrint('✅ [COMPLETE_SERVICE] FINAL update done');
    } catch (e) {
      debugPrint('❌ [COMPLETE_SERVICE_ERROR] $e');
    }

    debugPrint('==================================================');
  }
}
