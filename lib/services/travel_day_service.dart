import 'package:supabase_flutter/supabase_flutter.dart';

class TravelDayService {
  static final _supabase = Supabase.instance.client;

  /// yyyy-MM-dd
  static String _dateOnly(DateTime d) => d.toIso8601String().substring(0, 10);

  // =====================================================
  // 📌 특정 날짜 일기 조회
  // =====================================================
  static Future<Map<String, dynamic>?> getDiaryByDate({
    required String travelId,
    required DateTime date,
  }) async {
    return await _supabase
        .from('travel_days')
        .select()
        .eq('travel_id', travelId)
        .eq('date', _dateOnly(date))
        .maybeSingle();
  }

  // =====================================================
  // 💾 일기 저장 (없으면 insert, 있으면 update) - upsert
  // =====================================================
  static Future<Map<String, dynamic>> upsertDiary({
    required String travelId,
    required int dayIndex,
    required DateTime date,
    required String text,
    String? aiSummary,
    String? aiStyle,
  }) async {
    final res = await _supabase
        .from('travel_days')
        .upsert({
          'travel_id': travelId,
          'day_index': dayIndex,
          'date': _dateOnly(date),
          'text': text,
          if (aiSummary != null) 'ai_summary': aiSummary,
          if (aiStyle != null) 'ai_style': aiStyle,
        }, onConflict: 'travel_id,date')
        .select()
        .single();

    return res;
  }

  // =====================================================
  // ✍️ 작성된 일기 개수 (기록 상태용)
  // ✅ 버전 안 타게: rows 받아서 length로 계산
  // =====================================================
  static Future<int> getWrittenDayCount({required String travelId}) async {
    final res = await _supabase
        .from('travel_days')
        .select('id')
        .eq('travel_id', travelId)
        .not('text', 'is', null)
        .neq('text', '');

    // supabase dart는 select 결과가 List 형태
    if (res is List) return res.length;
    return 0;
  }

  // =====================================================
  // 🤖 AI 이미지 URL 계산 (DB 조회 ❌ / user 이미지 섞임 ❌)
  // - bucket: travel_images
  // - path: ai/{travelId}/{yyyy-MM-dd}.png
  // =====================================================
  static String getAiImageUrl({
    required String travelId,
    required DateTime date,
  }) {
    final fileName = '${_dateOnly(date)}.png';
    final path = 'ai/$travelId/$fileName';

    return _supabase.storage.from('travel_images').getPublicUrl(path);
  }

  // =====================================================
  // ✅ 별칭(혹시 다른 파일에서 이 이름으로 부르면 안 터지게)
  // "AI 이미지 = 일기 이미지" 컨셉 통일용
  // =====================================================
  static String getDiaryImageUrl({
    required String travelId,
    required DateTime date,
  }) {
    return getAiImageUrl(travelId: travelId, date: date);
  }
}
