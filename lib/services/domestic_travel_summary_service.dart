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
  // ✅ 최다 방문 지역 (형의 테이블 컬럼명 반영)
  static Future<List<String>> getMostVisitedRegions({
    required String userId,
    required bool isDomestic,
    bool? isCompleted,
    required String langCode,
  }) async {
    // 🎯 컬럼명 정확히: region_name, region_id
    var q = _supabase
        .from('travels')
        .select('region_name, region_id')
        .eq('user_id', userId)
        .eq('travel_type', isDomestic ? 'domestic' : 'overseas');

    if (isCompleted != null) {
      q = q.eq('is_completed', isCompleted);
    }

    final rows = await q;
    final map = <String, int>{};
    final bool isEn = langCode == 'en';

    for (final r in rows) {
      String? displayName;

      if (isEn) {
        // 🇺🇸 영어: region_id (KR_GB_BONGHWA) 에서 BONGHWA 추출
        final String regId = r['region_id']?.toString() ?? '';
        if (regId.contains('_')) {
          displayName = regId.split('_').last; // 마지막 단어 추출
        } else {
          displayName = r['country_name_en'] ?? 'TRAVEL'; // 없으면 기본값
        }
      } else {
        // 🇰🇷 한국어: region_name (봉화) 사용
        displayName = r['region_name'];
      }

      if (displayName == null || displayName.isEmpty) continue;
      map[displayName] = (map[displayName] ?? 0) + 1;
    }

    if (map.isEmpty) return [];

    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxVisitCount = sorted.first.value;

    return sorted
        .where((e) => e.value == maxVisitCount)
        .map((e) => isEn ? e.key.toUpperCase() : e.key)
        .toList();
  }

  // =====================================================
  // ✅ 방문 도시 수
  // =====================================================
  static Future<int> getUniqueVisitedRegionsCount({
    required String userId,
  }) async {
    // 1. DB에서 해당 유저의 모든 국내 여행 region_id를 싹 가져옴
    final response = await Supabase.instance.client
        .from('travels')
        .select('region_id')
        .eq('user_id', userId)
        .eq('travel_type', 'domestic');
    // .eq('is_completed', true);

    if (response == null) return 0;

    final List<dynamic> data = response as List<dynamic>;

    // 2. Set을 사용하여 포항 중복(2번)을 1개로 합침
    // id가 KR_SEOUL이든 KR_GB_BONGHWA이든 있는 그대로 다 담음
    final uniqueIds = data
        .map((item) => item['region_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    print("✅ 실제 방문 지역 목록: $uniqueIds"); // 여기서 12개가 들어있는지 확인!
    return uniqueIds.length; // 이제 12를 뱉어낼 거야
  }

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
