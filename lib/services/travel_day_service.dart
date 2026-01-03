import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel_memoir/storage_paths.dart';

class TravelDayService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// yyyy-MM-dd
  static String _dateOnly(DateTime d) => d.toIso8601String().substring(0, 10);

  // =====================================================
  // 🛡️ travel_day 정규화 (🔥 핵심)
  // =====================================================
  static Map<String, dynamic> _normalizeDay(Map<String, dynamic> day) {
    final String? text = day['text'] as String?;
    final String? aiSummary = day['ai_summary'] as String?;
    final String? aiStyle = day['ai_style'] as String?;
    final String? dateRaw = day['date'] as String?;

    return {
      ...day,
      'text': text?.trim() ?? '',
      'ai_summary': aiSummary?.trim() ?? '',
      'ai_style': (aiStyle != null && aiStyle.trim().isNotEmpty)
          ? aiStyle
          : 'default',
      'date': dateRaw ?? _dateOnly(DateTime.now()),
      'is_completed': day['is_completed'] == true,
    };
  }

  // =====================================================
  // 📌 특정 날짜 일기 조회
  // =====================================================
  static Future<Map<String, dynamic>?> getDiaryByDate({
    required String travelId,
    required DateTime date,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final res = await _supabase
        .from('travel_days')
        .select()
        .eq('travel_id', travelId)
        .eq('date', _dateOnly(date))
        .maybeSingle();

    if (res == null) return null;

    return _normalizeDay(Map<String, dynamic>.from(res));
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
          'text': text.trim(),
          'ai_summary': aiSummary?.trim(),
          'ai_style': aiStyle?.trim() ?? 'default',
        }, onConflict: 'travel_id,date')
        .select()
        .single();

    return _normalizeDay(Map<String, dynamic>.from(res));
  }

  // =====================================================
  // 🤖 AI 이미지 URL (🔥 수정됨: null-safe)
  // =====================================================
  static String? getAiImageUrl({
    required String travelId,
    required DateTime date,
  }) {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final path = StoragePaths.travelDayImage(
      user.id,
      travelId,
      _dateOnly(date),
    );

    return _supabase.storage.from('travel_images').getPublicUrl(path);
  }

  // =====================================================
  // ✅ 별칭
  // =====================================================
  static String? getDiaryImageUrl({
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
  // ✍️ 작성 완료된 일기 개수
  // =====================================================
  static Future<int> getWrittenDayCount({required String travelId}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;

    final res = await _supabase
        .from('travel_days')
        .select('text')
        .eq('travel_id', travelId);

    if (res is! List) return 0;

    return res.where((row) {
      final text = (row['text'] ?? '').toString().trim();
      return text.isNotEmpty;
    }).length;
  }

  static Future<List<Map<String, dynamic>>> getDiariesByTravel({
    required String travelId,
  }) async {
    final res = await _supabase
        .from('travel_days')
        .select()
        .eq('travel_id', travelId)
        .order('date');

    return List<Map<String, dynamic>>.from(res);
  }

  // =====================================================
  // 🖼️ 앨범용 날짜 목록
  // =====================================================
  static Future<List<Map<String, dynamic>>> getAlbumDays({
    required String travelId,
  }) async {
    final res = await _supabase
        .from('travel_days')
        .select('date, ai_summary')
        .eq('travel_id', travelId)
        .order('date', ascending: true);

    if (res == null || res is! List) return [];

    return res
        .where((e) => e['date'] != null)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<Map<String, dynamic>> getTravelById(String travelId) async {
    return await _supabase.from('travels').select().eq('id', travelId).single();
  }

  // =====================================================
  // 📸 사용자 사진 URL 저장 (현재 구조 유지)
  // =====================================================
  static Future<void> updateDiaryPhotos({
    required String travelId,
    required DateTime date,
    required List<String> photoUrls,
  }) async {
    print('🔥 updateDiaryPhotos');
    print('travelId=$travelId date=${_dateOnly(date)}');
    print('photoUrls=$photoUrls');

    await _supabase
        .from('travel_days')
        .update({'photo_urls': photoUrls})
        .eq('travel_id', travelId)
        .eq('date', _dateOnly(date));
  }
}
