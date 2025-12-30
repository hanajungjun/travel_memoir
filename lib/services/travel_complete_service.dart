import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/services/travel_day_service.dart';
import 'package:travel_memoir/services/gemini_service.dart';
import 'package:travel_memoir/services/image_upload_service.dart';
import 'package:travel_memoir/services/travel_highlight_service.dart';

import 'package:travel_memoir/core/constants/korea/sgg_code_map.dart';

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

    // ======================
    // 1️⃣ 여행 조회
    // ======================
    final travel = await _supabase
        .from('travels')
        .select()
        .eq('id', travelId)
        .single();

    debugPrint('🧪 [COMPLETE] travel=$travel');

    if (travel['is_completed'] == true) {
      debugPrint('⛔ [COMPLETE] already completed -> return');
      return;
    }

    // ======================
    // 2️⃣ 일기 개수 체크
    // ======================
    final writtenDays = await TravelDayService.getWrittenDayCount(
      travelId: travelId,
    );
    final totalDays = endDate.difference(startDate).inDays + 1;

    debugPrint('🧪 [COMPLETE] writtenDays=$writtenDays / totalDays=$totalDays');

    if (writtenDays < totalDays) {
      debugPrint('⛔ [COMPLETE] not enough diaries -> return');
      return;
    }

    // ======================
    // 3️⃣ 여행 완료 처리
    // ======================
    await _supabase
        .from('travels')
        .update({
          'is_completed': true,
          'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', travelId);

    debugPrint('✅ [COMPLETE] travel marked completed');

    // ======================
    // 4️⃣ 지도용 지역 upsert
    // ======================
    if (travel['travel_type'] == 'domestic') {
      final String? userId = travel['user_id'] as String?;
      final String? regionId = travel['region_id'] as String?;

      debugPrint(
        '🧭 [MAP] region mapping start userId=$userId regionId=$regionId',
      );

      if (userId != null && regionId != null) {
        final code = SggCodeMap.fromRegionId(regionId);

        debugPrint(
          '🧭 [MAP] mapped type=${code.type} '
          'sido=${code.sidoCd} sgg=${code.sggCd}',
        );

        await _supabase.from('domestic_travel_regions').upsert({
          'travel_id': travelId,
          'user_id': userId,
          'region_id': regionId,
          'map_region_id': regionId,
          'map_region_type': code.type,
          'sido_cd': code.sidoCd,
          'sgg_cd': code.sggCd,
        }, onConflict: 'user_id,region_id');

        debugPrint('✅ [MAP] upsert done');
      }
    }

    // ======================
    // 5️⃣ AI 처리
    // ======================
    final gemini = GeminiService();

    final String placeName =
        (travel['travel_type'] == 'domestic'
                ? travel['region_name']
                : travel['country_name'])
            ?.toString() ??
        '여행';

    debugPrint('🧠 [AI] placeName=$placeName');

    // ---------- 커버 이미지 ----------
    try {
      debugPrint('🖼️ [AI] cover image start');

      final row = await _supabase
          .from('ai_cover_map_prompts')
          .select('content')
          .eq('type', 'cover')
          .eq('is_active', true)
          .maybeSingle();

      debugPrint('🧪 [AI] cover prompt row=$row');

      if (row?['content'] != null) {
        final Uint8List bytes = await gemini.generateImage(
          finalPrompt: '${row!['content']}\nPlace: $placeName',
        );

        debugPrint('🧪 [AI] cover bytes length=${bytes.length}');

        if (bytes.isNotEmpty) {
          final url = await ImageUploadService.uploadTravelCoverImage(
            travelId: travelId,
            imageBytes: bytes,
          );

          await _supabase
              .from('travels')
              .update({'cover_image_url': url})
              .eq('id', travelId);

          debugPrint('✅ [AI] cover image uploaded');
        }
      }
    } catch (e, s) {
      debugPrint('❌ [AI] cover image failed: $e');
      debugPrint('$s');
    }

    // ---------- 지도 이미지 ----------
    try {
      debugPrint('🗺️ [AI] map image start');

      final row = await _supabase
          .from('ai_cover_map_prompts')
          .select('content')
          .eq('type', 'map')
          .eq('is_active', true)
          .maybeSingle();

      debugPrint('🧪 [AI] map prompt row=$row');

      if (row?['content'] != null) {
        final Uint8List bytes = await gemini.generateImage(
          finalPrompt: '${row!['content']}\nPlace: $placeName',
        );

        debugPrint('🧪 [AI] map bytes length=${bytes.length}');

        if (bytes.isNotEmpty) {
          final url = await ImageUploadService.uploadTravelMapImage(
            travelId: travelId,
            imageBytes: bytes,
          );

          await _supabase
              .from('travels')
              .update({'map_image_url': url})
              .eq('id', travelId);

          debugPrint('✅ [AI] map image uploaded');
        }
      }
    } catch (e, s) {
      debugPrint('❌ [AI] map image failed: $e');
      debugPrint('$s');
    }

    // ---------- 하이라이트 ----------
    try {
      debugPrint('✍️ [AI] highlight start');

      final highlight =
          await TravelHighlightService.generateHighlight(
            travelId: travelId,
            placeName: placeName,
          ) ??
          '';

      debugPrint('🧪 [AI] highlight="$highlight"');

      if (highlight.isNotEmpty) {
        await _supabase
            .from('travels')
            .update({'ai_cover_summary': highlight})
            .eq('id', travelId);

        debugPrint('✅ [AI] highlight saved');
      }
    } catch (e, s) {
      debugPrint('❌ [AI] highlight failed: $e');
      debugPrint('$s');
    }

    debugPrint('==============================');
    debugPrint('✅ [COMPLETE] tryCompleteTravel END');
    debugPrint('==============================');
  }
}
