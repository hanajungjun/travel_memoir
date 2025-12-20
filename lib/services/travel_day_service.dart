import 'package:supabase_flutter/supabase_flutter.dart';

class TravelDayService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// yyyy-MM-dd
  static String _dateOnly(DateTime d) => d.toIso8601String().substring(0, 10);

  // =====================================================
  // 📌 특정 날짜 일기 조회
  // =====================================================
  static Future<Map<String, dynamic>?> getDiaryByDate({
    required String travelId,
    required DateTime date,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    return await _supabase
        .from('travel_days')
        .select()
        .eq('travel_id', travelId)
        .eq('date', _dateOnly(date))
        .maybeSingle();
  }

  // =====================================================
  // 💾 일기 저장 (없으면 insert, 있으면 update)
  // =====================================================
  static Future<Map<String, dynamic>> upsertDiary({
    required String travelId,
    required int dayIndex,
    required DateTime date,
    required String text,
    String? aiSummary,
    String? aiStyle,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('로그인 필요');
    }

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
  // 🤖 AI 이미지 URL
  // bucket: travel_images
  // path: ai/{travelId}/{yyyy-MM-dd}.png
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
  // ✅ 별칭
  // =====================================================
  static String getDiaryImageUrl({
    required String travelId,
    required DateTime date,
  }) {
    return getAiImageUrl(travelId: travelId, date: date);
  }

  // =====================================================
  // ✅ 일기작성완료 + 여행완료 체크
  // =====================================================
  static Future<bool> completeDayAndCheckTravel({
    required String travelId,
    required DateTime date,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    // 1) 해당 날짜 일기 완료 처리
    await _supabase
        .from('travel_days')
        .update({'is_completed': true})
        .eq('travel_id', travelId)
        .eq('date', _dateOnly(date));

    // 2) 여행 정보 조회
    final travel = await _supabase
        .from('travels')
        .select('start_date, end_date, is_completed')
        .eq('id', travelId)
        .single();

    if (travel['is_completed'] == true) return false;

    final startDate = DateTime.parse(travel['start_date']);
    final endDate = DateTime.parse(travel['end_date']);
    final expectedDays = endDate.difference(startDate).inDays + 1;

    // 3) 완료된 일기 수
    final completedDays = await _supabase
        .from('travel_days')
        .select('id')
        .eq('travel_id', travelId)
        .eq('is_completed', true);

    if (completedDays.length != expectedDays) return false;

    // 4) 여행 완료 처리
    await _supabase
        .from('travels')
        .update({
          'is_completed': true,
          'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', travelId);

    return true;
  }

  // =====================================================
  // ✍️ 작성 완료된 일기 개수 (is_completed 기준)
  // =====================================================
  static Future<int> getWrittenDayCount({required String travelId}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;

    final res = await _supabase
        .from('travel_days')
        .select('id, text')
        .eq('travel_id', travelId);

    if (res is! List) return 0;

    // text가 실제로 채워진 row만 카운트
    return res.where((row) {
      final text = (row['text'] ?? '').toString().trim();
      return text.isNotEmpty;
    }).length;
  }
}
