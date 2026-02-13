import 'dart:ui';

class CountryModel {
  final String code; // KR
  final String nameEn; // South Korea
  final String nameKo; // 대한민국
  final double lat;
  final double lng;
  final String continent;
  final String? flagUrl;

  CountryModel({
    required this.code,
    required this.nameEn,
    required this.nameKo,
    required this.lat,
    required this.lng,
    required this.continent,
    this.flagUrl,
  });

  factory CountryModel.fromJson(Map<String, dynamic> json) {
    // 🇺🇸 영어 이름
    final nameEn = json['name']?['common'] ?? '';

    // 🇰🇷 한국어 이름 (없으면 영어로 fallback)
    final nameKo = json['translations']?['kor']?['common'] ?? nameEn;

    final code = json['cca2'] ?? '';

    // latlng 안전 처리
    final latlng = json['latlng'];
    final lat = latlng is List && latlng.isNotEmpty
        ? (latlng[0] as num).toDouble()
        : 0.0;
    final lng = latlng is List && latlng.length > 1
        ? (latlng[1] as num).toDouble()
        : 0.0;

    // continent 안전 처리
    final continents = json['continents'];
    final continent = continents is List && continents.isNotEmpty
        ? continents[0]
        : '';

    // flag 안전 처리
    final flags = json['flags'];
    final flagUrl = flags is Map<String, dynamic>
        ? flags['png'] as String?
        : null;

    return CountryModel(
      code: code,
      nameEn: nameEn,
      nameKo: nameKo,
      lat: lat,
      lng: lng,
      continent: continent,
      flagUrl: flagUrl,
    );
  }

  /// 📱 디바이스 언어에 맞는 국가명
  String displayName() {
    final lang = PlatformDispatcher.instance.locale.languageCode;

    if (lang == 'ko') {
      if (code.toUpperCase() == 'KP') return "북한(DPRK)";
      if (code.toUpperCase() == 'TR') return "튀르키예"; // 👈 추가
      return nameKo;
    }

    if (code.toUpperCase() == 'TR') return "Türkiye"; // 👈 영어도 추가
    return nameEn;
  }
}
