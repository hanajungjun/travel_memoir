import 'package:supabase_flutter/supabase_flutter.dart';

class DomesticTravelSummaryService {
  static final _supabase = Supabase.instance.client;

  // =====================================================
  // ✅ 방문한 지역 카운트
  // =====================================================
  static Future<Map<String, int>> getVisitedCountByArea({
    required String userId,
    required bool isDomestic,
    bool? isCompleted,
  }) async {
    final rows = await _supabase
        .from('visited_regions_view')
        .select('sido_cd')
        .eq('user_id', userId);

    final result = <String, int>{};
    for (final row in rows) {
      final sido = row['sido_cd']?.toString();
      if (sido == null) continue;
      result[sido] = (result[sido] ?? 0) + 1;
    }
    return result;
  }

  // =====================================================
  // ✅ 여행 횟수
  // =====================================================
  static Future<int> getTravelCount({
    required String userId,
    required bool isDomestic,
    bool? isCompleted,
  }) async {
    var q = _supabase
        .from('travels')
        .select('id')
        .eq('user_id', userId)
        .eq('travel_type', isDomestic ? 'domestic' : 'overseas');

    if (isCompleted != null) {
      q = q.eq('is_completed', isCompleted);
    }

    final rows = await q;
    return rows.length;
  }

  // =====================================================
  // ✅ 총 여행 일수
  // =====================================================
  static Future<int> getTotalTravelDays({
    required String userId,
    required bool isDomestic,
    bool? isCompleted,
  }) async {
    var q = _supabase
        .from('travels')
        .select('start_date, end_date')
        .eq('user_id', userId)
        .eq('travel_type', isDomestic ? 'domestic' : 'overseas');

    if (isCompleted != null) {
      q = q.eq('is_completed', isCompleted);
    }

    final rows = await q;
    int total = 0;

    for (final r in rows) {
      if (r['start_date'] == null || r['end_date'] == null) continue;
      final s = DateTime.parse(r['start_date']);
      final e = DateTime.parse(r['end_date']);
      total += e.difference(s).inDays + 1;
    }
    return total;
  }

  // =====================================================
  // ✅ 최다 방문 지역
  // =====================================================
  static Future<List<String>> getMostVisitedRegions({
    required String userId,
    required bool isDomestic,
    bool? isCompleted,
  }) async {
    var q = _supabase
        .from('travels')
        .select('region_name')
        .eq('user_id', userId)
        .eq('travel_type', isDomestic ? 'domestic' : 'overseas');

    if (isCompleted != null) {
      q = q.eq('is_completed', isCompleted);
    }

    final rows = await q;
    final map = <String, int>{};

    for (final r in rows) {
      final name = r['region_name']?.toString();
      if (name == null || name.isEmpty) continue;
      map[name] = (map[name] ?? 0) + 1;
    }

    if (map.isEmpty) return [];

    // 1. 전체 데이터 정렬 (기존 로직)
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 🎯 2. [수정 핵심] 최다 방문 횟수(Top 1)가 몇 번인지 찾기
    final maxVisitCount = sorted.first.value;

    // 🎯 3. [수정 핵심] 그 횟수와 동일한 지역들만 필터링 (공동 1등 포함)
    return sorted
        .where((e) => e.value == maxVisitCount) // 2번 간 곳이 최고면 2번 간 곳만 남김
        .map((e) => e.key)
        .toList();
  }

  // =====================================================
  // ✅ 방문 도시 수
  // =====================================================
  /*
  static Future<int> getVisitedCityCount({required String userId}) async {
    final rows = await _supabase
        .from('domestic_travel_regions')
        .select('sido_cd')
        .eq('user_id', userId);

    final set = <String>{};
    for (final r in rows) {
      final s = r['sido_cd']?.toString();
      if (s != null) set.add(s);
    }
    return set.length;
  }
  */

  // =====================================================
  // ✅ 완성된 추억 개수 (🔥 일기 전부 작성된 여행)
  // =====================================================
  static Future<int> getCompletedMemoriesCount({
    required String userId,
    required bool isDomestic,
  }) async {
    // 1. 여행 목록
    final travels = await _supabase
        .from('travels')
        .select('id, start_date, end_date')
        .eq('user_id', userId)
        .eq('travel_type', isDomestic ? 'domestic' : 'overseas');

    if (travels.isEmpty) return 0;

    final travelIds = travels
        .map((t) => t['id']?.toString())
        .whereType<String>()
        .toList();

    // 2. 일기 작성 수
    final days = await _supabase
        .from('travel_days')
        .select('travel_id, text, ai_summary')
        .inFilter('travel_id', travelIds);

    final written = <String, int>{};
    for (final d in days) {
      final id = d['travel_id']?.toString();
      if (id == null) continue;
      final text = d['text']?.toString().trim() ?? '';
      final summary = d['ai_summary']?.toString().trim() ?? '';
      if (text.isEmpty && summary.isEmpty) continue;
      written[id] = (written[id] ?? 0) + 1;
    }

    // 3. 기대 일수와 비교
    int completed = 0;
    for (final t in travels) {
      if (t['start_date'] == null || t['end_date'] == null) continue;
      final s = DateTime.parse(t['start_date']);
      final e = DateTime.parse(t['end_date']);
      final expected = e.difference(s).inDays + 1;
      final have = written[t['id']] ?? 0;
      if (have >= expected) completed++;
    }

    return completed;
  }
}
