import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/services/travel_day_service.dart';
import 'package:travel_memoir/services/gemini_service.dart';
import 'package:travel_memoir/services/image_upload_service.dart';
import 'package:travel_memoir/services/prompt_cache.dart';

class TravelCompleteService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<void> tryCompleteTravel({
    required String travelId,
    required String city,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // =================================
    // 1️⃣ 여행 조회
    // =================================
    final travel = await _supabase
        .from('travels')
        .select()
        .eq('id', travelId)
        .single();

    if (travel['is_completed'] == true) return;

    // =================================
    // 2️⃣ 모든 날짜 일기 작성 여부 확인
    // =================================
    final writtenDays = await TravelDayService.getWrittenDayCount(
      travelId: travelId,
    );

    final totalDays = endDate.difference(startDate).inDays + 1;
    if (writtenDays < totalDays) return;

    // =================================
    // 3️⃣ 여행 완료 처리
    // =================================
    await _supabase
        .from('travels')
        .update({
          'is_completed': true,
          'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', travelId);

    final gemini = GeminiService();

    // =================================
    // 4️⃣ AI 커버 이미지 생성 (🔥 다시 추가됨)
    // =================================
    final coverPrompt =
        '''
${PromptCache.imagePrompt.content}

Purpose: Travel cover illustration
City: $city

Style:
- Flat illustration
- Warm and calm mood
- No text
- Clean background
''';

    final coverBytes = await gemini.generateImage(finalPrompt: coverPrompt);

    final coverUrl = await ImageUploadService.uploadTravelCoverImage(
      travelId: travelId,
      imageBytes: coverBytes,
    );

    // =================================
    // 5️⃣ AI 지도 이미지 생성
    // =================================
    final mapPrompt =
        '''
${PromptCache.imagePrompt.content}

Purpose: Travel route map illustration
City: $city

Style:
- Simple flat map illustration
- Minimal labels
- Calm, clean background
''';

    final mapBytes = await gemini.generateImage(finalPrompt: mapPrompt);

    final mapUrl = await ImageUploadService.uploadTravelMapImage(
      travelId: travelId,
      imageBytes: mapBytes,
    );

    // =================================
    // 6️⃣ travels 테이블 업데이트
    // =================================
    await _supabase
        .from('travels')
        .update({'cover_image_url': coverUrl, 'map_image_url': mapUrl})
        .eq('id', travelId);
  }
}
