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
      final travel = await _supabase
          .from('travels')
          .select()
          .eq('id', travelId)
          .single();

      // 이미 완료되었더라도 커버 이미지가 없으면 로직을 통과시킴
      if (travel['is_completed'] == true && travel['cover_image_url'] != null) {
        debugPrint('⛔️ [COMPLETE_SERVICE] 이미 완료되었고 커버도 있습니다 → 리턴');
        return;
      }

      if (travel['is_completed'] == true && travel['cover_image_url'] != null) {
        return; // 중복 방지
      }

      final writtenDays = await TravelDayService.getWrittenDayCount(
        travelId: travelId,
      );

      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      final totalDays = end.difference(start).inDays + 1;

      if (writtenDays < totalDays) {
        debugPrint('⛔️ [COMPLETE_SERVICE] 일기 작성 부족 → 리턴');
        return;
      }

      final String travelType = travel['travel_type'] ?? 'domestic';
      final String? regionId = travel['region_id'];
      final bool isKo = PlatformDispatcher.instance.locale.languageCode == 'ko';

      // 1️⃣ 여행 완료 처리
      await _supabase
          .from('travels')
          .update({
            'is_completed': true,
            'completed_at': DateTime.now().toIso8601String(),
            if (travelType == 'domestic' && regionId != null)
              'region_key': regionId,
          })
          .eq('id', travelId);

      // 2️⃣ 국내 지역 upsert (해외 도장 로직은 여기서 삭제됨 🗑️)
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

      final String placeName =
          (travelType == 'domestic'
                  ? travel['region_name']
                  : (isKo
                        ? travel['country_name_ko']
                        : travel['country_name_en']))
              ?.toString() ??
          '여행';

      // 3️⃣ AI 커버 생성 + 업로드
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
          }
        }
      } catch (e) {
        debugPrint('❌ [COMPLETE_SERVICE] 커버 생성 에러: $e');
      }

      // 4️⃣ path 및 AI 요약 업데이트
      final coverPath = StoragePaths.travelCoverPath(userId, travelId);
      final Map<String, dynamic> finalUpdate = {'cover_image_url': coverPath};

      if (travelType == 'domestic' && regionId != null) {
        finalUpdate['map_image_url'] = '$regionId.png';
      }

      try {
        final summary = await TravelHighlightService.generateHighlight(
          travelId: travelId,
          placeName: placeName,
        );
        if (summary != null) {
          finalUpdate['ai_cover_summary'] = summary;
        }
      } catch (e) {
        debugPrint('❌ [COMPLETE_SERVICE] 요약 생성 에러: $e');
      }

      await _supabase.from('travels').update(finalUpdate).eq('id', travelId);
      debugPrint('✅ [COMPLETE_SERVICE] 모든 완료 로직 종료');
    } catch (e) {
      debugPrint('❌ [COMPLETE_SERVICE_ERROR] $e');
    }

    debugPrint('==================================================');
  }
}
