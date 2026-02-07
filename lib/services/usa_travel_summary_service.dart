import 'package:supabase_flutter/supabase_flutter.dart';

class UsaTravelSummaryService {
  static final _supabase = Supabase.instance.client;

  /// 1. 방문한 미국의 주(State) 개수 (중복 제거)
  static Future<int> getVisitedStateCount({required String userId}) async {
    try {
      final response = await _supabase
          .from('travels')
          .select('region_key')
          .eq('user_id', userId)
          .eq('travel_type', 'usa');

      final visitedStates = (response as List)
          .map((item) => item['region_key'] as String?)
          .where((state) => state != null && state.isNotEmpty)
          .toSet();

      return visitedStates.length; // ✅ count 대신 length 사용
    } catch (e) {
      return 0;
    }
  }

  /// 2. 전체 미국 여행 횟수
  static Future<int> getTravelCount({
    required String userId,
    String travelType = 'usa',
    bool? isCompleted,
  }) async {
    try {
      var query = _supabase
          .from('travels')
          .select('id')
          .eq('user_id', userId)
          .eq('travel_type', travelType);

      if (isCompleted != null) {
        query = query.eq('is_completed', isCompleted);
      }

      final List response = await query;
      return response.length; // ✅ PostgrestList는 List이므로 length 사용
    } catch (e) {
      return 0;
    }
  }

  /// 3. 완성된 추억 개수
  static Future<int> getCompletedMemoriesCount({
    required String userId,
    String travelType = 'usa',
  }) async {
    try {
      final List response = await _supabase
          .from('travels')
          .select('id')
          .eq('user_id', userId)
          .eq('travel_type', travelType)
          .eq('is_completed', true);

      return response.length; // ✅ length 사용
    } catch (e) {
      return 0;
    }
  }

  /// 4. 총 미국 여행 일수
  static Future<int> getTotalTravelDays({
    required String userId,
    String travelType = 'usa',
    bool? isCompleted,
  }) async {
    try {
      var query = _supabase
          .from('travels')
          .select('start_date, end_date')
          .eq('user_id', userId)
          .eq('travel_type', travelType);

      if (isCompleted != null) {
        query = query.eq('is_completed', isCompleted);
      }

      final List response = await query;
      int totalDays = 0;

      for (var travel in response) {
        final startStr = travel['start_date'] as String?;
        final endStr = travel['end_date'] as String?;

        if (startStr != null && endStr != null) {
          final start = DateTime.tryParse(startStr);
          final end = DateTime.tryParse(endStr);
          if (start != null && end != null) {
            totalDays += end.difference(start).inDays + 1;
          }
        }
      }
      return totalDays;
    } catch (e) {
      return 0;
    }
  }

  /// 5. 최다 방문 주 리스트 (공동 1위 필터링 적용)
  static Future<List<String>> getMostVisitedStates({
    required String userId,
    String travelType = 'usa',
    bool? isCompleted,
  }) async {
    try {
      var query = _supabase
          .from('travels')
          .select('region_key')
          .eq('user_id', userId)
          .eq('travel_type', travelType);

      if (isCompleted != null) {
        query = query.eq('is_completed', isCompleted);
      }

      final List response = await query;
      if (response.isEmpty) return [];

      final Map<String, int> counts = {};
      for (var travel in response) {
        final state = travel['region_key'] as String?;
        if (state != null && state.isNotEmpty) {
          counts[state] = (counts[state] ?? 0) + 1;
        }
      }

      if (counts.isEmpty) return [];

      // 1. 방문 횟수 순 정렬
      var sortedEntries = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // 🎯 2. [핵심 수정] 최다 방문 횟수 확인
      final maxVisitCount = sortedEntries.first.value;

      // 🎯 3. [핵심 수정] 최다 횟수와 동일한 지역들만 필터링
      return sortedEntries
          .where((e) => e.value == maxVisitCount)
          .map((e) => e.key)
          .toList();
    } catch (e) {
      return [];
    }
  }
}
