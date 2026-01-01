import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:travel_memoir/services/visited_region_service.dart';

class DomesticMapPage extends StatefulWidget {
  const DomesticMapPage({super.key});

  @override
  State<DomesticMapPage> createState() => _DomesticMapPageState();
}

class _DomesticMapPageState extends State<DomesticMapPage> {
  MapboxMap? _map;

  // 🔒 styleLoaded 중복 방지
  bool _styleInitialized = false;

  static const _sidoSourceId = 'korea-sido-source';
  static const _sigSourceId = 'korea-sig-source';

  static const _visitedSidoLayer = 'visited-sido-layer';
  static const _visitedSigLayer = 'visited-sig-layer';

  static const _borderSidoLayer = 'border-sido-layer';
  static const _borderSigLayer = 'border-sig-layer';

  static const _sidoGeoJson = 'assets/geo/processed/korea_sido.geojson';
  static const _sigGeoJson = 'assets/geo/processed/korea_sig.geojson';

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      cameraOptions: CameraOptions(
        center: Point(coordinates: Position(127.8, 36.3)),
        zoom: 5.2,
      ),
      // ✅ PageView 안에서도 지도 제스처 먹게 하는 핵심
      gestureRecognizers: {
        Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
      },
      onMapCreated: (map) => _map = map,
      onStyleLoadedListener: _onStyleLoaded,
    );
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData data) async {
    // 🔥 중복 방지
    if (_styleInitialized) {
      debugPrint('🛑 [MAP] style already initialized -> skip');
      return;
    }
    _styleInitialized = true;

    debugPrint('🗺️ [MAP] style loaded');

    final map = _map;
    if (map == null) return;

    // ✅ 여기서 Supabase user id 사용
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final rows = await VisitedRegionService.getVisitedRegionsAll(
      userId: user.id,
    );

    final Set<String> visitedSidoCodes = {};
    final Set<String> visitedSigunguCodes = {};

    for (final row in rows) {
      if (row['type'] == 'sido' && row['sido_cd'] != null) {
        visitedSidoCodes.add(row['sido_cd'].toString());
      }
      if (row['type'] == 'city' && row['sgg_cd'] != null) {
        visitedSigunguCodes.add(row['sgg_cd'].toString());
      }
    }

    final style = map.style;

    // ===== SIDO =====
    if (visitedSidoCodes.isNotEmpty) {
      final sidoGeojson = await rootBundle.loadString(_sidoGeoJson);

      await _rmSource(style, _sidoSourceId);
      await _rmLayer(style, _visitedSidoLayer);
      await _rmLayer(style, _borderSidoLayer);

      await style.addSource(
        GeoJsonSource(id: _sidoSourceId, data: sidoGeojson),
      );

      await style.addLayer(
        FillLayer(
          id: _visitedSidoLayer,
          sourceId: _sidoSourceId,
          filter: [
            'in',
            ['get', 'SIDO_CD'],
            ['literal', visitedSidoCodes.toList()],
          ],
          fillColor: 0xFFE53935,
          fillOpacity: 0.85,
        ),
      );

      await style.addLayer(
        LineLayer(
          id: _borderSidoLayer,
          sourceId: _sidoSourceId,
          lineColor: 0xFF333333,
          lineWidth: 1,
        ),
      );
    }

    // ===== SIGUNGU =====
    if (visitedSigunguCodes.isNotEmpty) {
      final sigGeojson = await rootBundle.loadString(_sigGeoJson);

      await _rmSource(style, _sigSourceId);
      await _rmLayer(style, _visitedSigLayer);
      await _rmLayer(style, _borderSigLayer);

      await style.addSource(GeoJsonSource(id: _sigSourceId, data: sigGeojson));

      await style.addLayer(
        FillLayer(
          id: _visitedSigLayer,
          sourceId: _sigSourceId,
          filter: [
            'in',
            ['get', 'SGG_CD'],
            ['literal', visitedSigunguCodes.toList()],
          ],
          fillColor: 0xFFE53935,
          fillOpacity: 0.85,
        ),
      );

      await style.addLayer(
        LineLayer(
          id: _borderSigLayer,
          sourceId: _sigSourceId,
          lineColor: 0xFF333333,
          lineWidth: 0.8,
        ),
      );
    }

    debugPrint('✅ map render done');
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
