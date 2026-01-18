import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class OverseasTravelSummaryService {
  static final _supabase = Supabase.instance.client;

  // =====================================================
  // 🌍 전체 국가 수
  // =====================================================
  static Future<int> getTotalCountryCount() async {
    final uri = Uri.parse('https://restcountries.com/v3.1/all?fields=cca2');
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch countries');
    }

    final List list = jsonDecode(res.body);
    return list.length;
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

    final sorted = countMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final isKo = PlatformDispatcher.instance.locale.languageCode == 'ko';

    return sorted.map((e) {
      final names = nameMap[e.key];
      return isKo ? (names?['ko'] ?? e.key) : (names?['en'] ?? e.key);
    }).toList();
  }
}
