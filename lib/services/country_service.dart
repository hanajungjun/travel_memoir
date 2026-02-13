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

      // 3. 필터링 및 이름 예외 처리
      final List<CountryModel> filteredCountries = decoded
          .map<CountryModel>((e) {
            final model = CountryModel.fromJson(e);
            final String code = model.code.toUpperCase();

            // 🎯 [특수 국가 이름 예외 처리]
            if (code == 'KP' || code == 'TR') {
              final Map<String, dynamic> customJson = Map.from(e);

              if (customJson['translations'] != null &&
                  customJson['translations']['kor'] != null) {
                if (code == 'KP') {
                  customJson['translations']['kor']['common'] = "북한(DPRK)";
                }
                // 🇹🇷 터키 -> 튀르키예 강제 치환
                else if (code == 'TR') {
                  customJson['translations']['kor']['common'] = "튀르키예";
                  // 필요하다면 영어 이름도 여기서 바꿀 수 있습니다.
                  customJson['name']['common'] = "Türkiye";
                }
              }

              return CountryModel.fromJson(customJson);
            }

            return model;
          })
          .where((country) {
            return validCodes.contains(country.code.toUpperCase());
          })
          .toList();
      // 4. 이름순 정렬
      filteredCountries.sort(
        (a, b) => a.displayName().compareTo(b.displayName()),
      );
      //final allCodes = filteredCountries.map((c) => c.code).toList();
      //debugPrint("✅ [181개 국가 코드 리스트]: ${allCodes.join(', ')}");
      // debugPrint(
      //   "📊 [결과] 전체 API: ${decoded.length}개 -> 지도 있는 나라: ${filteredCountries.length}개",
      // );

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

          // 1️⃣ ISO_A2 정상값 우선
          final isoA2 = props['ISO_A2'];
          if (isoA2 != null &&
              isoA2 is String &&
              isoA2.length == 2 &&
              isoA2 != '-99') {
            code = isoA2;
          }

          // 2️⃣ ISO_A2_EH fallback (France, UK, Norway 등)
          if (code == null) {
            final isoA2Eh = props['ISO_A2_EH'];
            if (isoA2Eh != null && isoA2Eh is String && isoA2Eh.length == 2) {
              code = isoA2Eh;
            }
          }

          // 3️⃣ WB_A2 최후 fallback
          if (code == null) {
            final wbA2 = props['WB_A2'];
            if (wbA2 != null && wbA2 is String && wbA2.length == 2) {
              code = wbA2;
            }
          }

          if (code != null) {
            codes.add(code.toUpperCase());
          }
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
