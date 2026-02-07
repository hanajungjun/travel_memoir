import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'country_service.dart';

class OverseasTravelSummaryService {
  static final _supabase = Supabase.instance.client;

  // 🔥 [추가] 전체 국가 수 캐시 변수
  static int? _totalCountryCountCache;

  // =====================================================
  // 🌍 전체 국가 수 (지도 필터링 반영 + 캐시 적용)
  // =====================================================
  static Future<int> getTotalCountryCount() async {
    return 181;
    /* 속도땀시그냥박음
    // 1. 캐시된 값이 있다면 즉시 반환
    if (_totalCountryCountCache != null) {
      debugPrint("💾 [SummaryService] 캐시된 국가 수 반환: $_totalCountryCountCache");
      return _totalCountryCountCache!;
    }

    try {
      debugPrint("📡 [SummaryService] 필터링된 국가 수 조회를 위해 CountryService 호출...");

      // 2. CountryService의 fetchAll()을 사용하여
      // GeoJSON에 실제 존재하는 국가 리스트만 가져옵니다.
      final countries = await CountryService.fetchAll();

      // 3. 결과값을 캐시에 저장
      _totalCountryCountCache = countries.length;

      debugPrint("📊 [SummaryService] 전체 국가 수 캐싱 완료: $_totalCountryCountCache");
      return _totalCountryCountCache!;
    } catch (e) {
      debugPrint("❌ [SummaryService] 국가 수 조회 실패: $e");

      // 에러 발생 시 기존처럼 API에서 직접 가져오는 로직(Fallback) 혹은 0 반환
      return 0;
    }
    */
  }

  // =====================================================
  // ✈️ 방문한 국가 수 (완료된 여행 기준)
  // =====================================================
  static Future<int> getVisitedCountryCount({required String userId}) async {
    final rows = await _supabase
        .from('travels')
        .select('country_code')
        .eq('user_id', userId)
        .eq('travel_type', 'overseas');
    //   .eq('is_completed', true);

    final visited = <String>{};
    for (final row in rows) {
      final code = row['country_code'];
      if (code != null) {
        visited.add(code.toString());
      }
    }

    return visited.length;
  }

  // =====================================================
  // ✈️ 해외 여행 횟수
  // =====================================================
  static Future<int> getTravelCount({
    required String userId,
    bool? isCompleted,
  }) async {
    var query = _supabase
        .from('travels')
        .select('id')
        .eq('user_id', userId)
        .eq('travel_type', 'overseas');

    if (isCompleted != null) {
      query = query.eq('is_completed', isCompleted);
    }

    final rows = await query;
    return rows.length;
  }

  // =====================================================
  // ✈️ 총 여행 일수 (🔥 완료 여부 선택)
  // =====================================================
  static Future<int> getTotalTravelDays({
    required String userId,
    bool? isCompleted,
  }) async {
    var query = _supabase
        .from('travels')
        .select('start_date, end_date')
        .eq('user_id', userId)
        .eq('travel_type', 'overseas');

    if (isCompleted != null) {
      query = query.eq('is_completed', isCompleted);
    }

    final rows = await query;
    int totalDays = 0;

    for (final row in rows) {
      final start = row['start_date'];
      final end = row['end_date'];
      if (start == null || end == null) continue;

      try {
        final s = DateTime.parse(start.toString());
        final e = DateTime.parse(end.toString());
        totalDays += e.difference(s).inDays + 1;
      } catch (_) {}
    }

    return totalDays;
  }

  // =====================================================
  // 🌍 최다 방문 국가 리스트 (많이 간 순, 다국어)
  // =====================================================
  // =====================================================
  // 🌍 최다 방문 국가 리스트 (공동 1위 필터링 적용)
  // =====================================================
  static Future<List<String>> getMostVisitedCountries({
    required String userId,
    bool? isCompleted,
  }) async {
    var query = _supabase
        .from('travels')
        .select('country_code, country_name_ko, country_name_en')
        .eq('user_id', userId)
        .eq('travel_type', 'overseas');

    if (isCompleted != null) {
      query = query.eq('is_completed', isCompleted);
    }

    final rows = await query;
    if (rows.isEmpty) return [];

    final countMap = <String, int>{};
    final nameMap = <String, Map<String, String>>{};

    for (final row in rows) {
      final code = row['country_code']?.toString();
      if (code == null || code.isEmpty) continue;

      countMap[code] = (countMap[code] ?? 0) + 1;
      nameMap[code] = {
        'ko': row['country_name_ko']?.toString() ?? '',
        'en': row['country_name_en']?.toString() ?? '',
      };
    }

    if (countMap.isEmpty) return [];

    // 1. 방문 횟수 순으로 정렬
    final sorted = countMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 🎯 2. [핵심 수정] 최다 방문 횟수가 몇 번인지 확인
    final maxVisitCount = sorted.first.value;

    // 🎯 3. [핵심 수정] 최다 방문 횟수와 동일한 국가만 필터링 (공동 1위 포함)
    final topCountries = sorted.where((e) => e.value == maxVisitCount).toList();

    final isKo = PlatformDispatcher.instance.locale.languageCode == 'ko';

    return topCountries.map((e) {
      final names = nameMap[e.key];
      return isKo ? (names?['ko'] ?? e.key) : (names?['en'] ?? e.key);
    }).toList();
  }

  // 🔥 [추가] 로그아웃 등을 할 때 캐시를 비워야 한다면 사용하세요.
  static void clearCache() {
    _totalCountryCountCache = null;
  }
}
