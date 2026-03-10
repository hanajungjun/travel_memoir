// detailed_map_config.dart
// 상세 지도(서브맵) 설정 모델 및 기본 목록

import 'package:travel_memoir/core/constants/app_colors.dart';

typedef UrlBuilder = String Function(String rawPath);

class DetailedMapConfig {
  final String countryCode;
  final String geoJsonPath;
  final String sourceId;
  final String layerId;
  final String labelLayerId;

  /// 팝업 이미지 URL을 생성하는 함수. null이면 globalMapFromPath 사용.
  final UrlBuilder? urlBuilder;

  const DetailedMapConfig({
    required this.countryCode,
    required this.geoJsonPath,
    required this.sourceId,
    required this.layerId,
    required this.labelLayerId,
    this.urlBuilder,
  });
}

/// 앱에서 지원하는 상세 지도 목록 (중앙 관리)
const List<DetailedMapConfig> kSupportedDetailedMaps = [
  DetailedMapConfig(
    countryCode: 'US',
    geoJsonPath: 'assets/geo/processed/usa_states_standard.json',
    sourceId: 'usa-source',
    layerId: 'usa-fill',
    labelLayerId: 'state-label',
  ),
  DetailedMapConfig(
    countryCode: 'JP',
    geoJsonPath: 'assets/geo/processed/japan_prefectures.json',
    sourceId: 'japan-source',
    layerId: 'japan-fill',
    labelLayerId: 'settlement-label',
  ),
  DetailedMapConfig(
    countryCode: 'IT',
    geoJsonPath: 'assets/geo/processed/italy_regions.json',
    sourceId: 'italy-source',
    layerId: 'italy-fill',
    labelLayerId: 'settlement-label',
  ),
];
