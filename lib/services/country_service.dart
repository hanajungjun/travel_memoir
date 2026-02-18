import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:travel_memoir/models/country_model.dart';

class CountryService {
  static List<CountryModel>? _cache; // ✅ 메모리 캐시

  // ✅ 앱 시작 시 백그라운드 워밍업
  static Future<void> prefetch() async {
    if (_cache != null) return;
    try {
      await fetchAll();
    } catch (_) {}
  }

  static Future<List<CountryModel>> fetchAll() async {
    if (_cache != null) return _cache!; // ✅ 캐시 있으면 즉시 반환

    try {
      debugPrint("🌍 [CountryService] cca2 기준으로 필터링 시작...");

      final Set<String> validCodes = await _loadGeoJsonCodes();

      final uri = Uri.parse(
        'https://restcountries.com/v3.1/all'
        '?fields=name,cca2,latlng,continents,translations,flags',
      );

      final res = await http.get(uri);
      if (res.statusCode != 200) throw Exception('API 호출 실패');

      final List<dynamic> decoded = jsonDecode(res.body);

      final List<CountryModel> filteredCountries = decoded
          .map<CountryModel>((e) {
            final model = CountryModel.fromJson(e);
            final String code = model.code.toUpperCase();

            if (code == 'KP' || code == 'TR') {
              final Map<String, dynamic> customJson = Map.from(e);
              if (customJson['translations'] != null &&
                  customJson['translations']['kor'] != null) {
                if (code == 'KP') {
                  customJson['translations']['kor']['common'] = "북한(DPRK)";
                } else if (code == 'TR') {
                  customJson['translations']['kor']['common'] = "튀르키예";
                  customJson['name']['common'] = "Türkiye";
                }
              }
              return CountryModel.fromJson(customJson);
            }

            return model;
          })
          .where((country) => validCodes.contains(country.code.toUpperCase()))
          .toList();

      filteredCountries.sort(
        (a, b) => a.displayName().compareTo(b.displayName()),
      );

      _cache = filteredCountries; // ✅ 캐시 저장
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
          final props = feature['properties'] ?? {};

          String? code;

          final isoA2 = props['ISO_A2'];
          if (isoA2 != null &&
              isoA2 is String &&
              isoA2.length == 2 &&
              isoA2 != '-99') {
            code = isoA2;
          }

          if (code == null) {
            final isoA2Eh = props['ISO_A2_EH'];
            if (isoA2Eh != null && isoA2Eh is String && isoA2Eh.length == 2) {
              code = isoA2Eh;
            }
          }

          if (code == null) {
            final wbA2 = props['WB_A2'];
            if (wbA2 != null && wbA2 is String && wbA2.length == 2) {
              code = wbA2;
            }
          }

          if (code != null) codes.add(code.toUpperCase());
        }
      }

      debugPrint('🗺️ [GeoJSON] valid ISO_A2 count=${codes.length}');
      return codes;
    } catch (e) {
      debugPrint("❌ GeoJSON 로드 실패: $e");
      return {};
    }
  }
}
