import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:easy_localization/easy_localization.dart'; // ✅ 추가

import '../models/country_model.dart';

class CountryService {
  static Future<List<CountryModel>> fetchAll() async {
    final uri = Uri.parse(
      'https://restcountries.com/v3.1/all'
      '?fields=name,cca2,latlng,continents,translations,flags',
    );

    final res = await http.get(uri, headers: {'Accept': 'application/json'});

    if (res.statusCode != 200) {
      // ✅ 에러 메시지 번역 및 상태 코드 전달
      throw Exception(
        'error_country_api_fail'.tr(args: [res.statusCode.toString()]),
      );
    }

    final List<dynamic> decoded = jsonDecode(res.body);

    final countries = decoded
        .map<CountryModel>((e) => CountryModel.fromJson(e))
        .where((c) => c.code.isNotEmpty)
        .toList();

    // ✅ 정렬 로직 (이름순)
    // displayName()이 모델 내부에서 현재 언어에 맞는 이름을 반환하므로 그대로 사용합니다.
    countries.sort((a, b) => a.displayName().compareTo(b.displayName()));

    return countries;
  }
}
