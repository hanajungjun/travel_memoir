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
    debugPrint('🚀 [COMPLETE_SERVICE] 작업 시작: $travelId');
    debugPrint(
      '📅 기간: ${startDate.toIso8601String().substring(0, 10)} ~ ${endDate.toIso8601String().substring(0, 10)}',
    );

    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint('❌ [ERROR] 유저 정보가 없습니다. 함수 종료.');
      return;
    }
    final userId = user.id;

    try {
      // 1️⃣ 여행 데이터 조회
      final travel = await _supabase
          .from('travels')
          .select()
          .eq('id', travelId)
          .single();

      if (travel['is_completed'] == true) {
        debugPrint('ℹ️ [SKIP] 이미 완료 처리된 여행입니다.');
        return;
      }

      // 2️⃣ 일기 작성 여부 체크 (가장 유력한 중단 지점)
      final writtenDays = await TravelDayService.getWrittenDayCount(
        travelId: travelId,
      );
      final totalDays = endDate.difference(startDate).inDays + 1;

      debugPrint('📊 [CHECK] 일기 작성 현황: $writtenDays / $totalDays');

      if (writtenDays < totalDays) {
        debugPrint('⚠️ [STOP] 일기 개수가 부족합니다. (완료 조건 미충족)');
        debugPrint('==================================================');
        return;
      }

      debugPrint('✅ [PASS] 모든 일기 작성 확인. 완료 처리 진행...');

      final String travelType = travel['travel_type'] ?? 'domestic';
      final String? regionId = travel['region_id'];
      final bool isKo = PlatformDispatcher.instance.locale.languageCode == 'ko';

      // 3️⃣ 1차 업데이트: 여행 완료 상태 변경
      debugPrint('📝 [DB_UPDATE] 1차: is_completed -> true');
      Map<String, dynamic> updateData = {
        'is_completed': true,
        'completed_at': DateTime.now().toIso8601String(),
      };

      if (travelType == 'domestic' && regionId != null) {
        updateData['region_key'] = regionId;
      }

      await _supabase.from('travels').update(updateData).eq('id', travelId);

      // 4️⃣ 국내 지역 전용 데이터 처리
      if (travelType == 'domestic' && regionId != null) {
        debugPrint('🇰🇷 [DOMESTIC] 국내 지역 데이터(upsert) 처리 중...');
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

      final String placeName =
          (travelType == 'domestic'
                  ? travel['region_name']
                  : (isKo
                        ? travel['country_name_ko']
                        : travel['country_name_en']))
              ?.toString() ??
          '여행';

      // 5️⃣ AI Cover 이미지 생성 (Gemini-Imagen)
      debugPrint('🎨 [AI_GEN] 커버 이미지 생성 시작 (장소: $placeName)...');
      try {
        final promptRow = await _supabase
            .from('ai_cover_map_prompts')
            .select('content')
            .eq('type', 'cover')
            .eq('is_active', true)
            .maybeSingle();
        if (promptRow?['content'] != null) {
          final bytes = await GeminiService().generateImage(
            finalPrompt: '${promptRow!['content']}\nPlace: $placeName',
          );
          if (bytes.isNotEmpty) {
            await ImageUploadService.uploadTravelCover(
              userId: userId,
              travelId: travelId,
              imageBytes: bytes,
            );
            debugPrint('✅ [AI_GEN] 커버 이미지 업로드 완료');
          }
        }
      } catch (e) {
        debugPrint('❌ [AI_GEN_ERROR] 커버 이미지 생성 실패: $e');
      }

      // 6️⃣ 2차 업데이트: 이미지 URL 세팅
      debugPrint('🔗 [DB_UPDATE] 2차: 이미지 URL 및 요약 정보 업데이트...');
      final coverPath = StoragePaths.travelCover(userId, travelId);
      final coverUrl = _supabase.storage
          .from('travel_images')
          .getPublicUrl(coverPath);

      Map<String, dynamic> finalUpdate = {'cover_image_url': coverUrl};

      if (travelType == 'domestic' && regionId != null) {
        finalUpdate['map_image_url'] = _supabase.storage
            .from('map_images')
            .getPublicUrl('$regionId.png');
      }

      // 7️⃣ 여행 하이라이트 요약 (Gemini)
      try {
        debugPrint('✍️ [AI_SUMMARY] 여행 요약 생성 중...');
        final summary = await TravelHighlightService.generateHighlight(
          travelId: travelId,
          placeName: placeName,
        );
        if (summary != null) {
          finalUpdate['ai_cover_summary'] = summary;
          debugPrint('✅ [AI_SUMMARY] 요약 완료');
        }
      } catch (e) {
        debugPrint('❌ [AI_SUMMARY_ERROR] 요약 생성 실패: $e');
      }

      await _supabase.from('travels').update(finalUpdate).eq('id', travelId);
      debugPrint('🏁 [COMPLETE_SERVICE] 모든 작업 성공적으로 완료!');
    } catch (e) {
      debugPrint('❌ [CRITICAL_ERROR] 완료 처리 중 심각한 오류 발생: $e');
    }
    debugPrint('==================================================');
  }
}
