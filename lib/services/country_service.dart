import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/country_model.dart';

class CountryService {
  static Future<List<CountryModel>> fetchAll() async {
    final uri = Uri.parse(
      'https://restcountries.com/v3.1/all'
      '?fields=name,cca2,latlng,continents',
    );

    final res = await http.get(uri, headers: {'Accept': 'application/json'});

    if (res.statusCode != 200) {
      throw Exception('국가 API 실패 (${res.statusCode})');
    }

    final decoded = jsonDecode(res.body);

    if (decoded is! List) {
      throw Exception('국가 API 형식 오류');
    }

    final countries =
        decoded
            .map<CountryModel>((e) => CountryModel.fromJson(e))
            .where((c) => c.code.isNotEmpty)
            .toList()
          ..sort((a, b) => a.displayName().compareTo(b.displayName()));

    return countries;
  }
}
