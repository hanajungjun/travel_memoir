import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel_memoir/core/constants/korea/korea_region.dart';
import 'package:travel_memoir/core/constants/korea/korea_regions.dart';

class DomesticRegionSummaryService {
  static final _supabase = Supabase.instance.client;

  /// 권역 정의
  static const Map<String, List<String>> _regionGroups = {
    '수도권': ['서울', '경기', '인천'],
    '영남': ['부산', '대구', '울산', '경남', '경북'],
    '호남': ['광주', '전남', '전북'],
    '충청': ['대전', '세종', '충남', '충북'],
    '강원': ['강원'],
    '제주': ['제주'],
  };

  /// ✅ 권역별 방문 개수 계산
  /// return 예:
  /// {
  ///   '수도권': 1,
  ///   '영남': 2,
  ///   '호남': 1,
  /// }
  static Future<Map<String, int>> getVisitedCountByRegion({
    required String userId,
  }) async {
    // 1️⃣ 완료된 여행의 region_id 가져오기
    final res = await _supabase
        .from('travels')
        .select('region_id')
        .eq('user_id', userId)
        .eq('is_completed', true);

    if (res.isEmpty) {
      return {};
    }

    // 2️⃣ 방문한 region_id 집합 (중복 제거)
    final visitedRegionIds = res
        .map<String?>((e) => e['region_id'] as String?)
        .whereType<String>()
        .toSet();

    // 3️⃣ 권역별 방문 province Set
    final Map<String, Set<String>> visitedByGroup = {
      for (final key in _regionGroups.keys) key: <String>{},
    };

    for (final regionId in visitedRegionIds) {
      KoreaRegion? region;

      try {
        region = koreaRegions.firstWhere((r) => r.id == regionId);
      } catch (_) {
        region = null;
      }

      if (region == null) continue;

      final province = region.province;

      for (final entry in _regionGroups.entries) {
        if (entry.value.contains(province)) {
          visitedByGroup[entry.key]!.add(region.id);
          break;
        }
      }
    }

    // 6️⃣ Set 길이 → count
    final Map<String, int> result = {};
    for (final entry in visitedByGroup.entries) {
      result[entry.key] = entry.value.length;
    }

    return result;
  }
}
