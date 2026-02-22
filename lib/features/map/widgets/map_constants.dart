// map_constants.dart
// 맵 관련 모든 상수값 중앙 관리

class MapConstants {
  MapConstants._();

  // ── Source / Layer IDs ──────────────────────────────────────────────────
  static const String worldSource = 'world-source';
  static const String worldFillLayer = 'world-fill';

  // ── Asset 경로 ───────────────────────────────────────────────────────────
  static const String worldGeoJson =
      'assets/geo/processed/world_countries.geojson';

  // ── 카메라 기본값 ─────────────────────────────────────────────────────────
  static const double defaultLng = 10.0;
  static const double defaultLat = 20.0;
  static const double defaultZoom = 1.3;
  static const double minZoom = 0.8;
  static const double maxZoom = 6.0;

  // ── 포커스 ────────────────────────────────────────────────────────────────
  static const double focusZoom = 3.5;
  static const double antarcticaMaxLat = -60.0;
  static const double antarcticaZoom = 0.5;
  static const int flyToDurationMs = 2500;

  // ── Fill 투명도 ───────────────────────────────────────────────────────────
  static const double defaultOpacity = 0.7;
  static const double usBaseOpacity = 0.25; // 미국 전국 레이어(서브맵 활성 시 반투명)
  static const double usVisitedOpacity = 0.7;
  static const double usActiveOpacity = 0.3; // 방문했지만 미완료 주

  // ── 초기화 딜레이 ─────────────────────────────────────────────────────────
  static const int initDelayMs = 500;
  static const int subMapDelayMs = 50;

  // ── 특수 국가 코드 ────────────────────────────────────────────────────────
  static const String kosovoCode = 'XK';
  static const String usCode = 'US';
}
