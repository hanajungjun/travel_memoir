import 'package:supabase_flutter/supabase_flutter.dart';

class DomesticTravelSummaryService {
  static final _supabase = Supabase.instance.client;

  // ✅ 방문한 지역을 조회하는 쿼리 (안전하게 수정)
  static Future<Map<String, int>> getVisitedCountByArea({
    required String userId,
    required bool isDomestic,
    required bool isCompleted,
  }) async {
    try {
      final rows = await _supabase
          .from('visited_regions_view')
          .select('sido_cd')
          .eq('user_id', userId);

      final result = <String, int>{};

      for (final row in rows) {
        final sidoCd = row['sido_cd']?.toString();
        if (sidoCd == null) continue;
        result[sidoCd] = (result[sidoCd] ?? 0) + 1;
      }
      return result;
    } catch (e) {
      return {};
    }
  }

  // ✅ 여행 횟수 조회 (안전하게 수정)
  static Future<int> getTravelCount({
    required String userId,
    required bool isDomestic,
    required bool isCompleted,
  }) async {
    try {
      final rows = await _supabase
          .from('travels')
          .select('id')
          .eq('user_id', userId)
          .eq('is_completed', isCompleted)
          .eq('travel_type', isDomestic ? 'domestic' : 'overseas');

      return rows.length;
    } catch (e) {
      return 0;
    }
  }

  // ✅ 여행 일수 조회 (안전하게 수정)
  static Future<int> getTotalTravelDays({
    required String userId,
    required bool isDomestic,
    required bool isCompleted,
  }) async {
    try {
      final rows = await _supabase
          .from('travels')
          .select('start_date, end_date')
          .eq('user_id', userId)
          .eq('is_completed', isCompleted)
          .eq('travel_type', isDomestic ? 'domestic' : 'overseas');

      int totalDays = 0;

      for (final row in rows) {
        final startDateStr = row['start_date'];
        final endDateStr = row['end_date'];

        if (startDateStr != null && endDateStr != null) {
          try {
            final startDate = DateTime.parse(startDateStr);
            final endDate = DateTime.parse(endDateStr);
            final difference =
                endDate.difference(startDate).inDays + 1; // 당일 여행도 1일로 처리
            totalDays += difference;
          } catch (e) {
            continue;
          }
        }
      }
      return totalDays;
    } catch (e) {
      return 0;
    }
  }

  // ✅ 가장 많이 방문한 지역 조회 (🔥 에러 원인 해결!)
  static Future<String> getMostVisitedRegion({
    required String userId,
    required bool isDomestic,
    required bool isCompleted,
  }) async {
    try {
      final rows = await _supabase
          .from('travels')
          .select('region_name')
          .eq('user_id', userId)
          .eq('is_completed', isCompleted)
          .eq('travel_type', isDomestic ? 'domestic' : 'overseas');

      if (rows.isEmpty) return '-'; // 데이터 없으면 즉시 반환

      final regionCount = <String, int>{};

      for (final row in rows) {
        final region = row['region_name']?.toString();
        if (region != null) {
          regionCount[region] = (regionCount[region] ?? 0) + 1;
        }
      }

      // 비어있지 않을 때만 reduce 실행
      if (regionCount.isEmpty) return '-';

      final mostVisitedRegion = regionCount.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;

      return mostVisitedRegion;
    } catch (e) {
      return '-';
    }
  }

  // ✅ 방문한 도시 수 조회 (안전하게 수정)
  static Future<int> getVisitedCityCount({required String userId}) async {
    try {
      final rows = await _supabase
          .from('domestic_travel_regions')
          .select('sido_cd')
          .eq('user_id', userId);

      return rows.length;
    } catch (e) {
      return 0;
    }
  }
}
