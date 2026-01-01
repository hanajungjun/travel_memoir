import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/services/overseas_travel_service.dart';

class GlobalMapPage extends StatefulWidget {
  const GlobalMapPage({super.key});

  @override
  State<GlobalMapPage> createState() => _GlobalMapPageState();
}

class _GlobalMapPageState extends State<GlobalMapPage> {
  MapboxMap? _map;
  bool _styleInitialized = false;

  static const _worldSourceId = 'world-country-source';
  static const _visitedCountryLayer = 'visited-country-layer';
  static const _borderCountryLayer = 'border-country-layer';

  static const _worldGeoJson = 'assets/geo/processed/world_countries.geojson';

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      // ✅ 평면처럼 보이는 세계지도 기본 카메라
      cameraOptions: CameraOptions(
        center: Point(coordinates: Position(0, 20)),
        zoom: 2.2,
        bearing: 0,
        pitch: 0,
      ),

      // ✅ pinch 확대/축소 정상
      gestureRecognizers: {
        Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
        Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
      },

      onMapCreated: (map) async {
        _map = map;

        // 🔒 줌 범위만 제한 (지구본 느낌 방지)
        await map.setBounds(CameraBoundsOptions(minZoom: 1.4, maxZoom: 6.0));
      },

      // 🔥 여기서 색칠 + 핀 + 조회 전부 처리
      onStyleLoadedListener: _onStyleLoaded,
    );
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData data) async {
    if (_styleInitialized) return;
    _styleInitialized = true;

    debugPrint('🌍 [GLOBAL MAP] style loaded');

    final map = _map;
    if (map == null) return;

    final style = map.style;

    // =========================
    // 1️⃣ 해외 여행 조회
    // =========================
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final travels = await OverseasTravelService.getOverseasTravels(
      userId: user.id,
    );

    if (travels.isEmpty) return;

    // 국가 코드 모으기
    final Set<String> countryCodes = {};
    for (final t in travels) {
      final code = t['country_code'];
      if (code != null) {
        countryCodes.add(code.toString());
      }
    }

    // =========================
    // 2️⃣ 세계 GeoJSON 로드
    // =========================
    final worldGeoJson = await rootBundle.loadString(_worldGeoJson);

    await _rmLayer(style, _visitedCountryLayer);
    await _rmLayer(style, _borderCountryLayer);
    await _rmSource(style, _worldSourceId);

    await style.addSource(
      GeoJsonSource(id: _worldSourceId, data: worldGeoJson),
    );

    // =========================
    // 3️⃣ 방문 국가 색칠
    // 👉 ISO_A2_EH 사용 (TW, AS 대응)
    // =========================
    await style.addLayer(
      FillLayer(
        id: _visitedCountryLayer,
        sourceId: _worldSourceId,
        filter: [
          'in',
          ['get', 'ISO_A2_EH'],
          ['literal', countryCodes.toList()],
        ],
        fillColor: 0xFF4FC3F7,
        fillOpacity: 0.6,
      ),
    );

    await style.addLayer(
      LineLayer(
        id: _borderCountryLayer,
        sourceId: _worldSourceId,
        lineColor: 0xFF333333,
        lineWidth: 0.5,
      ),
    );

    // =========================
    // 4️⃣ 핀 찍기 (geocode)
    // =========================
    final pointManager = await map.annotations.createPointAnnotationManager();

    for (final travel in travels) {
      final countryName = travel['country_name'];
      if (countryName == null) continue;

      try {
        final res = await OverseasTravelService.geocode(query: countryName);

        if (res == null || res['found'] != true) continue;

        final lat = res['lat'];
        final lng = res['lng'];

        await pointManager.create(
          PointAnnotationOptions(
            geometry: Point(coordinates: Position(lng, lat)),
            iconImage: 'marker-15',
            iconSize: 1.6,
          ),
        );
      } catch (e) {
        debugPrint('❌ [GEOCODE FAIL] $countryName → $e');
      }
    }

    debugPrint('✅ [GLOBAL MAP] render done');
    // =========================
    // 5️⃣ 마지막 여행지로 센터만 이동 (줌 유지)
    // =========================
    if (travels.isNotEmpty) {
      final last = travels.last;
      final countryName = last['country_name'];

      if (countryName != null) {
        try {
          final res = await OverseasTravelService.geocode(query: countryName);

          if (res != null && res['found'] == true) {
            final lat = res['lat'];
            final lng = res['lng'];

            await map.easeTo(
              CameraOptions(center: Point(coordinates: Position(lng, lat))),
              MapAnimationOptions(
                duration: 1000, // ms
              ),
            );
          }
        } catch (_) {
          // 실패해도 지도는 그대로
        }
      }
    }
  }

  Future<void> _rmLayer(StyleManager style, String id) async {
    try {
      await style.removeStyleLayer(id);
    } catch (_) {}
  }

  Future<void> _rmSource(StyleManager style, String id) async {
    try {
      await style.removeStyleSource(id);
    } catch (_) {}
  }
}
