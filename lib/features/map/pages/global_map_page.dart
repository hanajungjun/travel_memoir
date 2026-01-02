import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel_memoir/services/overseas_travel_service.dart';

class GlobalMapPage extends StatefulWidget {
  // ✅ 요약 페이지 등에서 고정된 지도를 보여주기 위한 변수 추가
  final bool isReadOnly;

  const GlobalMapPage({
    super.key,
    this.isReadOnly = false, // 기본값은 false
  });

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
      cameraOptions: CameraOptions(
        center: Point(coordinates: Position(10.0, 20.0)),
        // ✅ 읽기 전용일 때는 줌을 더 낮춤 (0.1) 아니면 일반 줌 (0.5)
        zoom: widget.isReadOnly ? 0.1 : 0.5,
        bearing: 0,
        pitch: 0,
      ),
      mapOptions: MapOptions(
        pixelRatio: MediaQuery.of(context).devicePixelRatio,
      ),
      // ✅ 읽기 전용일 때는 제스처를 비활성화할 수도 있습니다 (선택사항)
      gestureRecognizers: widget.isReadOnly
          ? {}
          : {
              Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
              Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
            },
      onMapCreated: (map) async {
        _map = map;
        await map.gestures.updateSettings(
          GesturesSettings(pitchEnabled: false),
        );
        // 최소 줌 제한을 0으로 둡니다.
        await map.setBounds(CameraBoundsOptions(minZoom: 0.0, maxZoom: 8.0));
      },
      onStyleLoadedListener: _onStyleLoaded,
    );
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData data) async {
    if (_styleInitialized) return;
    _styleInitialized = true;

    final map = _map;
    if (map == null) return;
    final style = map.style;

    try {
      await style.setProjection(
        StyleProjection(name: StyleProjectionName.mercator),
      );
    } catch (e) {
      debugPrint('⚠️ Projection setting failed: $e');
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final travels = await OverseasTravelService.getOverseasTravels(
      userId: user.id,
    );
    final worldGeoJson = await rootBundle.loadString(_worldGeoJson);

    await _rmLayer(style, _visitedCountryLayer);
    await _rmLayer(style, _borderCountryLayer);
    await _rmSource(style, _worldSourceId);

    await style.addSource(
      GeoJsonSource(id: _worldSourceId, data: worldGeoJson),
    );

    if (travels.isNotEmpty) {
      final Set<String> countryCodes = {};
      for (final t in travels) {
        final code = t['country_code'];
        if (code != null) countryCodes.add(code.toString());
      }

      final visitedLayer = FillLayer(
        id: _visitedCountryLayer,
        sourceId: _worldSourceId,
      );
      visitedLayer.filter = [
        'in',
        ['get', 'ISO_A2_EH'],
        ['literal', countryCodes.toList()],
      ];
      visitedLayer.fillColor = 0xFF4FC3F7;
      visitedLayer.fillOpacity = 0.6;
      await style.addLayer(visitedLayer);
    }

    final borderLayer = LineLayer(
      id: _borderCountryLayer,
      sourceId: _worldSourceId,
    );
    borderLayer.lineColor = 0xFF333333;
    borderLayer.lineWidth = 0.5;
    await style.addLayer(borderLayer);

    final pointManager = await map.annotations.createPointAnnotationManager();
    Map<String, double>? lastLocation;

    for (final travel in travels) {
      final countryName = travel['country_name'];
      if (countryName == null) continue;
      try {
        final res = await OverseasTravelService.geocode(query: countryName);
        if (res != null && res['found'] == true) {
          final lat = res['lat'] as double;
          final lng = res['lng'] as double;

          await pointManager.create(
            PointAnnotationOptions(
              geometry: Point(coordinates: Position(lng, lat)),
              iconImage: 'marker-15',
              iconSize: 1.6,
            ),
          );
          lastLocation = {'lat': lat, 'lng': lng};
        }
      } catch (e) {
        debugPrint('❌ [GEOCODE FAIL] $countryName → $e');
      }
    }

    // ✅ 핵심: isReadOnly가 false일 때만 마지막 위치로 이동(애니메이션) 실행
    if (!widget.isReadOnly && lastLocation != null) {
      await map.easeTo(
        CameraOptions(
          center: Point(
            coordinates: Position(lastLocation['lng']!, lastLocation['lat']!),
          ),
          zoom: 1.5,
        ),
        MapAnimationOptions(duration: 1500),
      );
    } /*
    else {
      
      debugPrint('ℹ️ No travels or last location available for centering.');

      CameraOptions(
        center: Point(coordinates: Position(10.0, 20.0)),
        zoom: 0,
        bearing: 0,
        pitch: 0,
      );
      await map.gestures.updateSettings(
        GesturesSettings(
          scrollEnabled: true, // 화면 스크롤(이동)만 활성화
          pitchEnabled: false, // 기울기 비활성화
          rotateEnabled: false, // 회전 비활성화
        ),
      );
    }
    */
  }

  Future<void> _rmLayer(StyleManager style, String id) async {
    try {
      if (await style.styleLayerExists(id)) await style.removeStyleLayer(id);
    } catch (_) {}
  }

  Future<void> _rmSource(StyleManager style, String id) async {
    try {
      if (await style.styleSourceExists(id)) await style.removeStyleSource(id);
    } catch (_) {}
  }
}
