import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class OverseasTravelSummaryService {
  static final _supabase = Supabase.instance.client;

  /// 🌍 전체 국가 수 (REST Countries)
  static Future<int> getTotalCountryCount() async {
    final uri = Uri.parse('https://restcountries.com/v3.1/all?fields=cca2');

    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch countries');
    }

    final List list = jsonDecode(res.body);
    return list.length;
  }

  /// ✈️ 방문한 국가 수 (중복 제거)
  static Future<int> getVisitedCountryCount({required String userId}) async {
    final rows = await _supabase
        .from('travels') // 'travels' 테이블에서
        .select('country_code') // 국가 코드만 가져옵니다
        .eq('travel_type', 'overseas') // 해외 여행 타입만
        .eq('is_completed', true); // 완료된 여행만

    final visited = <String>{};

    for (final row in rows) {
      final code = row['country_code'];
      if (code != null) {
        visited.add(code.toString());
      }
    }

    return visited.length;
  }

  /// ✈️ 해외 여행 요약 정보
  static Future<Map<String, dynamic>> getTravelSummary(String userId) async {
    final travelCount = await _getTravelCount(userId);
    final totalTravelDays = await _getTotalTravelDays(userId);
    final mostVisitedCountry = await _getMostVisitedCountry(userId);

    return {
      'travelCount': travelCount,
      'travelDays': totalTravelDays,
      'mostVisitedCountry': mostVisitedCountry,
    };
  }

  /// 해외 여행 횟수
  static Future<int> _getTravelCount(String userId) async {
    final rows = await _supabase
        .from('travels')
        .select()
        .eq('user_id', userId)
        .eq('travel_type', 'overseas')
        .eq('is_completed', true);

    return rows.length;
  }

  // ✅ 여행 일수 조회 (최종 정답)
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

        // 🔥 핵심: 항상 +1
        totalDays += diff + 1;
      } catch (e) {
        debugPrint('Error parsing dates: $e');
      }
    }

    return totalDays;
  }

  /// 가장 많이 간 국가
  static Future<String> _getMostVisitedCountry(String userId) async {
    final rows = await _supabase
        .from('travels')
        .select('country_name')
        .eq('user_id', userId)
        .eq('travel_type', 'overseas')
        .eq('is_completed', true);

    final Map<String, int> countryCount = {};

    for (final row in rows) {
      final raw = row['country_name'];
      final countryName = raw?.toString().trim();

      if (countryName == null || countryName.isEmpty) continue;

      countryCount[countryName] = (countryCount[countryName] ?? 0) + 1;
    }

    // 🔥 이 줄이 없으면 언젠가 반드시 터짐
    if (countryCount.isEmpty) {
      return '-';
    }

    return countryCount.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  /// ✈️ 해외 여행 횟수 (외부용)
  static Future<int> getTravelCount({required String userId}) async {
    return _getTravelCount(userId);
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
