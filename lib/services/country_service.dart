import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:travel_memoir/models/country_model.dart';

class CountryService {
  static Future<List<CountryModel>> fetchAll() async {
    try {
      debugPrint("🌍 [CountryService] cca2 기준으로 필터링 시작...");

      // 1. GeoJSON에서 ISO_A2 코드 세트 추출
      final Set<String> validCodes = await _loadGeoJsonCodes();

      // 2. API 호출
      final uri = Uri.parse(
        'https://restcountries.com/v3.1/all'
        '?fields=name,cca2,latlng,continents,translations,flags',
      );

      final res = await http.get(uri);
      if (res.statusCode != 200) throw Exception('API 호출 실패');

      final List<dynamic> decoded = jsonDecode(res.body);

      // 3. 필터링: API 국가 중 GeoJSON(ISO_A2)에 존재하는 나라만 포함
      final List<CountryModel> filteredCountries = decoded
          .map<CountryModel>((e) => CountryModel.fromJson(e))
          .where((country) => validCodes.contains(country.code.toUpperCase()))
          .toList();

      // 4. 이름순 정렬
      filteredCountries.sort(
        (a, b) => a.displayName().compareTo(b.displayName()),
      );

      debugPrint(
        "📊 [결과] 전체 API: ${decoded.length}개 -> 지도 있는 나라: ${filteredCountries.length}개",
      );
      return filteredCountries;
    } catch (e) {
      debugPrint("❌ 에러 발생: $e");
      rethrow;
    }
  }

  static Future<Set<String>> _loadGeoJsonCodes() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/geo/processed/world_countries.geojson',
      );
      final Map<String, dynamic> data = jsonDecode(jsonString);
      final Set<String> codes = {};

      if (data['features'] != null) {
        for (var feature in data['features']) {
          // ✅ GeoJSON의 properties['ISO_A2'] 사용
          final String? code = feature['properties']?['ISO_A2'];
          if (code != null && code.isNotEmpty) {
            codes.add(code.toUpperCase());
          }
        }
      }
      return codes;
    } catch (e) {
      debugPrint("❌ GeoJSON 로드 실패: $e");
      return {};
    }
  }
}
