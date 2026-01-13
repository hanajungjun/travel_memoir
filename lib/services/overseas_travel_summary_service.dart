import 'dart:convert';
import 'dart:ui'; // PlatformDispatcher 사용을 위해 필요
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class OverseasTravelSummaryService {
  static final _supabase = Supabase.instance.client;

  /// 🌍 전체 국가 수 (REST Countries API - 기존 로직 유지)
  static Future<int> getTotalCountryCount() async {
    final uri = Uri.parse('https://restcountries.com/v3.1/all?fields=cca2');
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch countries');
    }

    final List list = jsonDecode(res.body);
    return list.length;
  }

  /// ✈️ 방문한 국가 수 (중복 제거 - 기존 'is_completed: true' 로직 유지)
  static Future<int> getVisitedCountryCount({required String userId}) async {
    final rows = await _supabase
        .from('travels')
        .select('country_code')
        .eq('user_id', userId) // 유저 필터 추가
        .eq('travel_type', 'overseas')
        .eq('is_completed', true);

    final visited = <String>{};
    for (final row in rows) {
      final code = row['country_code'];
      if (code != null) {
        visited.add(code.toString());
      }
    }
    return visited.length;
  }

  /// ✈️ 해외 여행 요약 정보 (기존 로직 유지)
  static Future<Map<String, dynamic>> getTravelSummary(String userId) async {
    // 내부적으로 완료된 것만 집계하던 기존 동작 유지를 위해 true 전달
    final travelCount = await _getTravelCount(userId, true);
    final totalTravelDays = await _getTotalTravelDays(userId);
    final mostVisitedCountry = await _getMostVisitedCountry(userId);

    return {
      'travelCount': travelCount,
      'travelDays': totalTravelDays,
      'mostVisitedCountry': mostVisitedCountry,
    };
  }

  /// ✈️ [핵심 수정] 해외 여행 횟수 조회 (내부 로직)
  static Future<int> _getTravelCount(String userId, bool? isCompleted) async {
    var query = _supabase
        .from('travels')
        .select()
        .eq('user_id', userId)
        .eq('travel_type', 'overseas');

    // ✅ 선택적으로 필터 적용
    if (isCompleted != null) {
      query = query.eq('is_completed', isCompleted);
    }

    final rows = await query;
    return rows.length;
  }

  /// ✅ 여행 일수 조회 (유저님의 +1 계산 로직 그대로 복구)
  static Future<int> _getTotalTravelDays(String userId) async {
    final rows = await _supabase
        .from('travels')
        .select('start_date, end_date')
        .eq('user_id', userId)
        .eq('is_completed', true)
        .eq('travel_type', 'overseas');

    int totalDays = 0;
    for (final row in rows) {
      final startDateStr = row['start_date'];
      final endDateStr = row['end_date'];

      if (startDateStr == null || endDateStr == null) continue;

      try {
        final startDate = DateTime.parse(startDateStr.toString());
        final endDate = DateTime.parse(endDateStr.toString());
        final diff = endDate.difference(startDate).inDays;

        // 🔥 유저님의 핵심 로직: 항상 +1
        totalDays += diff + 1;
      } catch (e) {
        debugPrint('Error parsing dates: $e');
      }
    }
    return totalDays;
  }

  /// ✅ 가장 많이 간 국가 (다국어 대응 및 코드 기준 집계 로직 그대로 복구)
  static Future<String> _getMostVisitedCountry(String userId) async {
    final rows = await _supabase
        .from('travels')
        .select('country_code, country_name_ko, country_name_en')
        .eq('user_id', userId)
        .eq('travel_type', 'overseas')
        .eq('is_completed', true);

    if (rows.isEmpty) return '-';

    final Map<String, int> countryCount = {};
    final Map<String, Map<String, String>> countryNames = {};

    for (final row in rows) {
      final String? code = row['country_code']?.toString();
      if (code == null || code.isEmpty) continue;

      countryCount[code] = (countryCount[code] ?? 0) + 1;
      countryNames[code] = {
        'ko': row['country_name_ko']?.toString() ?? '',
        'en': row['country_name_en']?.toString() ?? '',
      };
    }

    if (countryCount.isEmpty) return '-';

    final String mostVisitedCode = countryCount.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    // 🌐 다국어 처리 로직 유지
    final bool isKo = PlatformDispatcher.instance.locale.languageCode == 'ko';
    final names = countryNames[mostVisitedCode];
    final String resultName = isKo
        ? (names?['ko'] ?? '')
        : (names?['en'] ?? '');

    return resultName.isNotEmpty ? resultName : '-';
  }

  // --- 외부 노출용 메서드 (순서대로 복구) ---

  /// ✈️ 해외 여행 횟수 (외부용 - 이제 isCompleted 가능)
  static Future<int> getTravelCount({
    required String userId,
    bool? isCompleted,
  }) async {
    return _getTravelCount(userId, isCompleted);
  }

  /// ✈️ 해외 여행 총 일수 (외부용)
  static Future<int> getTotalTravelDays({required String userId}) async {
    return _getTotalTravelDays(userId);
  }

  /// 🌍 가장 많이 간 국가 (외부용)
  static Future<String> getMostVisitedCountry({required String userId}) async {
    return _getMostVisitedCountry(userId);
  }
}
