import 'package:supabase_flutter/supabase_flutter.dart';

class DomesticTravelSummaryService {
  static final _supabase = Supabase.instance.client;

  // 방문한 지역을 조회하는 쿼리 (충청남도 기준으로)
  static Future<Map<String, int>> getVisitedCountByArea({
    required String userId,
    required bool isDomestic, // 국내 여행 여부 (이건 로직에 필요 없을 수도 있음)
    required bool isCompleted, // 완료된 여행 여부
  }) async {
    final rows = await _supabase
        .from('visited_regions_view')
        .select('sido_cd') // sido_cd를 기준으로 조회
        .eq('user_id', userId); // 특정 사용자 ID에 대한 조회

    final result = <String, int>{};

    // sido_cd를 기준으로 방문 지역 카운트
    for (final row in rows) {
      final sidoCd = row['sido_cd']?.toString(); // sido_cd 값을 문자열로 처리
      if (sidoCd == null) continue;

      // sido_cd를 기준으로 카운트
      result[sidoCd] = (result[sidoCd] ?? 0) + 1;
    }

    return result;
  }

  // ✅ 여행 횟수 조회
  static Future<int> getTravelCount({
    required String userId,
    required bool isDomestic,
    required bool isCompleted,
  }) async {
    final rows = await _supabase
        .from('travels')
        .select('id')
        .eq('user_id', userId)
        .eq('is_completed', isCompleted)
        .eq('travel_type', isDomestic ? 'domestic' : 'overseas');

    return rows.length;
  }

  // ✅ 여행 일수 조회 (수정된 코드)
  static Future<int> getTotalTravelDays({
    required String userId,
    required bool isDomestic,
    required bool isCompleted,
  }) async {
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

      // 시작일과 종료일이 모두 존재하는지 확인
      if (startDateStr != null && endDateStr != null) {
        try {
          final startDate = DateTime.parse(startDateStr);
          final endDate = DateTime.parse(endDateStr);

          // 시작일과 종료일이 동일한 경우에도 1일을 추가하도록 처리
          final difference = endDate.difference(startDate).inDays;

          // 차이가 0일이라면, 최소 1일로 계산
          totalDays += difference < 1 ? 1 : difference;
        } catch (e) {
          print('Error parsing dates: $e');
        }
      }
    }

    return totalDays;
  }

  // ✅ 가장 많이 방문한 지역 조회
  static Future<String> getMostVisitedRegion({
    required String userId,
    required bool isDomestic,
    required bool isCompleted,
  }) async {
    final rows = await _supabase
        .from('travels')
        .select('region_name')
        .eq('user_id', userId)
        .eq('is_completed', isCompleted)
        .eq('travel_type', isDomestic ? 'domestic' : 'overseas');

    final regionCount = <String, int>{};

    for (final row in rows) {
      final region = row['region_name']?.toString();
      if (region != null) {
        regionCount[region] = (regionCount[region] ?? 0) + 1;
      }
    }

    final mostVisitedRegion = regionCount.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    return mostVisitedRegion;
  }

  // 방문한 도시 수 조회
  static Future<int> getVisitedCityCount({required String userId}) async {
    // 사용자가 방문한 도시 수 조회 (여기서는 'city' 타입의 지역을 카운트)
    final rows = await _supabase
        .from('domestic_travel_regions')
        .select('sido_cd') // 'sido_cd'를 기준으로 조회
        .eq('user_id', userId);
    //    .eq('map_region_type', 'city'); // 'city' 타입만

    return rows.length; // 방문한 도시 수
  }
}
