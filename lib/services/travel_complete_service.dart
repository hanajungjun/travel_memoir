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
    // 0️⃣ 유저 확인
    // ======================
    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint('⛔ [COMPLETE] no user');
      return;
    }
    final userId = user.id;

    // ======================
    // 1️⃣ 여행 조회
    // ======================
    final travel = await _supabase
        .from('travels')
        .select()
        .eq('id', travelId)
        .single();

    if (travel['is_completed'] == true) {
      debugPrint('⛔ [COMPLETE] already completed');
      return;
    }

    // ======================
    // 2️⃣ 일기 개수 체크
    // ======================
    final writtenDays = await TravelDayService.getWrittenDayCount(
      travelId: travelId,
    );
    final totalDays = endDate.difference(startDate).inDays + 1;

    if (writtenDays < totalDays) {
      debugPrint('⛔ [COMPLETE] not enough diaries');
      return;
    }

    // ======================
    // 3️⃣ 여행 완료 처리 (DB)
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
    // 4️⃣ 국내 지도 region upsert
    // ======================
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
        }, onConflict: 'user_id,region_id');
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

    // ---------- 커버 이미지 ----------
    try {
      final row = await _supabase
          .from('ai_cover_map_prompts')
          .select('content')
          .eq('type', 'cover')
          .eq('is_active', true)
          .maybeSingle();

      if (row?['content'] != null) {
        final Uint8List bytes = await gemini.generateImage(
          finalPrompt: '${row!['content']}\nPlace: $placeName',
        );

        if (bytes.isNotEmpty) {
          await ImageUploadService.uploadTravelCover(
            userId: userId,
            travelId: travelId,
            imageBytes: bytes,
          );
          debugPrint('✅ [AI] cover uploaded');
        }
      }
    } catch (e, s) {
      debugPrint('❌ [AI] cover failed: $e');
      debugPrint('$s');
    }

    // ---------- 지도 이미지 ----------
    try {
      final row = await _supabase
          .from('ai_cover_map_prompts')
          .select('content')
          .eq('type', 'map')
          .eq('is_active', true)
          .maybeSingle();

      if (row?['content'] != null) {
        final Uint8List bytes = await gemini.generateImage(
          finalPrompt: '${row!['content']}\nPlace: $placeName',
        );

        if (bytes.isNotEmpty) {
          await ImageUploadService.uploadTravelMap(
            userId: userId,
            travelId: travelId,
            imageBytes: bytes,
          );
          debugPrint('✅ [AI] map uploaded');
        }
      }
    } catch (e, s) {
      debugPrint('❌ [AI] map failed: $e');
      debugPrint('$s');
    }

    // ---------- 하이라이트 ----------
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
