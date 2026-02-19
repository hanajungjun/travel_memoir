import 'dart:ui';
import 'package:intl/intl.dart';
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
    required String languageCode,
  }) async {
    debugPrint('🚀 [COMPLETE_SERVICE] START travelId=$travelId');

    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final userId = user.id;

    try {
      // 1. 기초 데이터 로드
      final travel = await _supabase
          .from('travels')
          .select()
          .eq('id', travelId)
          .single();

      // 🎯 이미 완료됐고 커버까지 있으면 진짜로 종료
      if (travel['is_completed'] == true && travel['cover_image_url'] != null) {
        debugPrint('⛔️ [COMPLETE_SERVICE] 이미 완료됨 → 리턴');
        return;
      }

      // 2. 작성 일기 수 체크
      final writtenDays = await TravelDayService.getWrittenDayCount(
        travelId: travelId,
      );
      final totalDays = endDate.difference(startDate).inDays + 1;
      if (writtenDays < totalDays) {
        debugPrint('⛔️ [COMPLETE_SERVICE] 일기 부족 ($writtenDays/$totalDays)');
        return;
      }

      final String travelType = travel['travel_type'] ?? 'domestic';
      final String? regionId = travel['region_id'];
      final String regionName = travel['region_name'] ?? '';

      // 3. AI용 장소 이름 확정 (placeName)
      String placeName = '';
      String finalPlaceForAi = '';

      if (travelType == 'usa') {
        placeName =
            (travel['region_name'] ?? travel['country_name_en'] ?? 'USA')
                .toString()
                .toUpperCase();
        finalPlaceForAi = "$placeName, a state in the USA";
      } else if (travelType == 'domestic') {
        final String regId = travel['region_id']?.toString() ?? '';
        placeName = regId.contains('_')
            ? regId.split('_').last.toUpperCase()
            : 'KOREA';
        finalPlaceForAi = "$placeName($regionName), South Korea";
      } else {
        placeName =
            (travel['country_name_en'] ?? travel['country_code'] ?? 'Global')
                .toString()
                .toUpperCase();
        finalPlaceForAi = placeName;
      }

      // --- 여기서부터 중요: 결과를 담을 변수들 ---
      String? coverPath;
      String? summary;

      // 4. [AI 이미지 생성] - DB 업데이트 전에 먼저 실행
      try {
        final promptRow = await _supabase
            .from('ai_cover_map_prompts')
            .select('content')
            .eq('type', 'cover')
            .eq('is_active', true)
            .maybeSingle();
        if (promptRow != null) {
          debugPrint('🤖 [AI] 커버 이미지 생성 시작...');
          final bytes = await GeminiService().generateImage(
            finalPrompt: '${promptRow['content']}\nPlace: $finalPlaceForAi',
          );
          if (bytes.isNotEmpty) {
            await ImageUploadService.uploadTravelCover(
              userId: userId,
              travelId: travelId,
              imageBytes: bytes,
            );
            coverPath = StoragePaths.travelCoverPath(userId, travelId);
            debugPrint('✅ [AI] 커버 업로드 완료');
          }
        }
      } catch (e) {
        debugPrint('❌ [AI] 커버 생성 중 에러 (무시하고 진행): $e');
      }

      // 5. [AI 요약 생성] - 역시 DB 업데이트 전에 실행
      try {
        debugPrint('🤖 [AI] 여행 하이라이트 요약 시작...');
        summary = await TravelHighlightService.generateHighlight(
          travelId: travelId,
          placeName: placeName,
          languageCode: languageCode,
        );
        debugPrint('✅ [AI] 요약 완료: $summary');
      } catch (e) {
        debugPrint('❌ [AI] 요약 생성 중 에러 (무시하고 진행): $e');
      }

      // 6. [최종 DB 업데이트] 모든 결과를 모아서 '딱 한 번'만 업데이트!
      debugPrint('💾 [DB] 최종 완료 데이터 저장 중...');
      final Map<String, dynamic> finalUpdate = {
        'is_completed': true,
        'completed_at': DateTime.now().toIso8601String(),
        if (coverPath != null) 'cover_image_url': coverPath,
        if (summary != null) 'ai_cover_summary': summary,
        if (travelType == 'domestic' && regionId != null)
          'region_key': regionId,
        if (travelType == 'domestic' && regionId != null)
          'map_image_url': '$regionId.webp',
      };

      await _supabase.from('travels').update(finalUpdate).eq('id', travelId);

      // 7. 국내 여행이면 도장 찍기 (별도 처리)
      if (travelType == 'domestic' && regionId != null) {
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

      debugPrint('🎉 [COMPLETE_SERVICE] 모든 완료 로직 성공!');
    } catch (e) {
      debugPrint('❌ [COMPLETE_SERVICE_ERROR] 치명적 오류: $e');
    }
  }
}
