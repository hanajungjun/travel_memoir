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

    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final userId = user.id;

    try {
      final travel = await _supabase
          .from('travels')
          .select()
          .eq('id', travelId)
          .single();

      if (travel['is_completed'] == true) return;

      final writtenDays = await TravelDayService.getWrittenDayCount(
        travelId: travelId,
      );
      final totalDays = endDate.difference(startDate).inDays + 1;
      if (writtenDays < totalDays) return;

      final String travelType = travel['travel_type'] ?? 'domestic';
      final String? regionId = travel['region_id'];
      final bool isKo = PlatformDispatcher.instance.locale.languageCode == 'ko';

      // 1️⃣ 완료 처리
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
      } catch (_) {}

      // 4️⃣ path 저장
      final coverPath = StoragePaths.travelCoverPath(userId, travelId);

      final Map<String, dynamic> finalUpdate = {'cover_image_url': coverPath};

      if (travelType == 'domestic' && regionId != null) {
        finalUpdate['map_image_url'] = '$regionId.png';
      }

      // 5️⃣ AI 요약
      try {
        final summary = await TravelHighlightService.generateHighlight(
          travelId: travelId,
          placeName: placeName,
        );
        if (summary != null) {
          finalUpdate['ai_cover_summary'] = summary;
        }
      } catch (_) {}

      await _supabase.from('travels').update(finalUpdate).eq('id', travelId);
    } catch (e) {
      debugPrint('❌ [COMPLETE_SERVICE_ERROR] $e');
    }

    debugPrint('==================================================');
  }
}
