import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/country_model.dart';

class CountryService {
  static Future<List<CountryModel>> fetchAll() async {
    final uri = Uri.parse(
      'https://restcountries.com/v3.1/all'
      // ✅ translations와 flags를 필드에 추가합니다.
      '?fields=name,cca2,latlng,continents,translations,flags',
    );

    final res = await http.get(uri, headers: {'Accept': 'application/json'});

    if (res.statusCode != 200) {
      throw Exception('국가 API 실패 (${res.statusCode})');
    }

    final List<dynamic> decoded = jsonDecode(res.body);

    final countries = decoded
        .map<CountryModel>((e) => CountryModel.fromJson(e))
        .where((c) => c.code.isNotEmpty)
        .toList();

    // ✅ 정렬 로직 (이름순)
    countries.sort((a, b) => a.displayName().compareTo(b.displayName()));

    return countries;
  }
}
