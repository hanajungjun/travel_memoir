// travel_map_data.dart
// Supabase에서 가져온 여행 데이터를 맵 렌더링용으로 정리하는 모델

class TravelMapData {
  final Set<String> visitedCountries;
  final Set<String> completedCountries;

  /// key: 국가코드(대문자), value: 방문한 지역명(대문자) 집합
  final Map<String, Set<String>> visitedRegions;

  /// key: 국가코드(대문자), value: 완료된 지역명(대문자) 집합
  final Map<String, Set<String>> completedRegions;

  const TravelMapData({
    required this.visitedCountries,
    required this.completedCountries,
    required this.visitedRegions,
    required this.completedRegions,
  });

  factory TravelMapData.empty() => TravelMapData(
        visitedCountries: {},
        completedCountries: {},
        visitedRegions: {},
        completedRegions: {},
      );

  /// Supabase rows → TravelMapData 변환
  factory TravelMapData.fromRows(List<dynamic> rows) {
    final Set<String> visited   = {};
    final Set<String> completed = {};
    final Map<String, Set<String>> visitedRegions   = {};
    final Map<String, Set<String>> completedRegions = {};

    for (final t in rows) {
      final code = t['country_code']?.toString().toUpperCase() ?? '';
      if (code.isEmpty) continue;

      visited.add(code);
      if (t['is_completed'] == true) completed.add(code);

      final rn = t['region_name']?.toString();
      if (rn != null) {
        final upper = rn.toUpperCase();
        visitedRegions.putIfAbsent(code, () => {}).add(upper);
        if (t['is_completed'] == true) {
          completedRegions.putIfAbsent(code, () => {}).add(upper);
        }
      }
    }

    return TravelMapData(
      visitedCountries:  visited,
      completedCountries: completed,
      visitedRegions:    visitedRegions,
      completedRegions:  completedRegions,
    );
  }
}
