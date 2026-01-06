import 'dart:convert'; // ✅ JSON 변환을 위해 필수 추가
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/services/visited_region_service.dart';

import 'package:travel_memoir/core/widgets/ai_map_popup.dart';

class DomesticMapPage extends StatefulWidget {
  const DomesticMapPage({super.key});

  @override
  State<DomesticMapPage> createState() => _DomesticMapPageState();
}

class _DomesticMapPageState extends State<DomesticMapPage> {
  MapboxMap? _map;
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
    return Scaffold(
      body: MapWidget(
        styleUri: "mapbox://styles/hanajungjun/cmjztbzby003i01sth91eayzw",
        cameraOptions: CameraOptions(
          center: Point(coordinates: Position(127.8, 36.3)),
          zoom: 5.2,
        ),
        gestureRecognizers: {
          Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
        },
        onMapCreated: (map) => _map = map,
        onStyleLoadedListener: _onStyleLoaded,
        onTapListener: (context) => _onMapTap(context),
      ),
    );
  }

  // =========================================================
  // 🖱️ 지도 클릭 핸들러
  // =========================================================
  Future<void> _onMapTap(MapContentGestureContext context) async {
    final map = _map;
    if (map == null) return;

    try {
      final screenCoordinate = await map.pixelForCoordinate(context.point);
      final features = await map.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screenCoordinate),
        RenderedQueryOptions(layerIds: [_visitedSidoLayer, _visitedSigLayer]),
      );

      if (features.isNotEmpty) {
        final props =
            features.first?.queriedFeature.feature['properties'] as Map?;
        if (props != null) {
          // 📍 '대구광역시' -> '대구'로 정제하여 DB 검색 정확도를 높임
          String sidoName = props['SIDO_NM']?.toString() ?? '';
          sidoName = sidoName
              .replaceAll('광역시', '')
              .replaceAll('특별', '')
              .replaceAll('자치', '')
              .trim();

          final String sggName = props['SGG_NM']?.toString() ?? '';
          final String code = props['SGG_CD'] ?? props['SIDO_CD'] ?? '';

          debugPrint('📍 클릭 감지: $sidoName ($code)');

          // 정제된 '대구'를 우선 순위로 쿼리문에 넘깁니다.
          _showAiMapPopup(code, sidoName.isNotEmpty ? sidoName : sggName);
        }
      }
    } catch (e) {
      debugPrint('❌ 클릭 쿼리 에러: $e');
    }
  }

  // =========================================================
  // 🎨 2. AI 이미지 팝업 (정확한 지역 필터링 추가)
  // =========================================================
  void _showAiMapPopup(String code, String name) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // 🔍 [데이터 필터링 강화] 단순히 최근 데이터가 아니라,
      // 현재 클릭한 지역(name)이 포함된 국내 여행 데이터만 가져옵니다.
      final response = await Supabase.instance.client
          .from('travels')
          .select('map_image_url, region_name, ai_cover_summary')
          .eq('user_id', user.id)
          .eq('travel_type', 'domestic') // 🇰🇷 국내 데이터 한정
          .ilike('region_name', '%$name%') // 📍 누른 지역(예: 대구) 검색
          .not('map_image_url', 'is', null)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      // 일치하는 지역의 기록이 없으면 팝업을 띄우지 않습니다.
      if (response == null || response['map_image_url'] == null) {
        debugPrint('ℹ️ $name 지역의 기록을 찾을 수 없습니다.');
        return;
      }

      if (!mounted) return;

      final String aiImageUrl = response['map_image_url'];
      final String summary = response['ai_cover_summary'] ?? "기록된 추억이 없습니다.";

      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: "AI Map",
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
        transitionBuilder: (context, anim1, anim2, child) {
          final curvedValue = Curves.easeOutBack.transform(anim1.value);

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX((1 - curvedValue) * 1.5),
            alignment: Alignment.bottomCenter,
            child: Opacity(
              opacity: anim1.value.clamp(0.0, 1.0),
              child: AiMapPopup(
                imageUrl: aiImageUrl, // ✅ 이제 일본 대신 대구 이미지가 나옵니다!
                regionName: name,
                summary: summary, // ✅ 요약도 대구 기록으로 나옵니다!
              ),
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('❌ 조회 에러: $e');
    }
  }

  // =========================================================
  // 🗺️ 3. 스타일 로드 및 한글화
  // =========================================================
  Future<void> _onStyleLoaded(StyleLoadedEventData data) async {
    if (_styleInitialized) return;
    _styleInitialized = true;

    final map = _map;
    if (map == null) return;
    final style = map.style;

    try {
      // 2D 평면 지도로 투영법 고정
      await style.setProjection(
        StyleProjection(name: StyleProjectionName.mercator),
      );

      // 한글화 처리
      final layers = await style.getStyleLayers();
      for (var layer in layers) {
        final id = layer?.id;
        if (id != null &&
            (id.contains('label') ||
                id.contains('place') ||
                id.contains('settlement'))) {
          try {
            await style.setStyleLayerProperty(
              id,
              'text-field',
              '["get", "name_ko"]',
            );
          } catch (_) {}
        }
      }

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

      if (visitedSidoCodes.isNotEmpty) {
        final sidoGeojson = await rootBundle.loadString(_sidoGeoJson);
        await _rmLayer(style, _visitedSidoLayer);
        await _rmSource(style, _sidoSourceId);
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
            fillColor: AppColors.mapVisitedFill.value,
            fillOpacity: 0.85,
          ),
        );
      }

      if (visitedSigunguCodes.isNotEmpty) {
        final sigGeojson = await rootBundle.loadString(_sigGeoJson);
        await _rmLayer(style, _visitedSigLayer);
        await _rmSource(style, _sigSourceId);
        await style.addSource(
          GeoJsonSource(id: _sigSourceId, data: sigGeojson),
        );
        await style.addLayer(
          FillLayer(
            id: _visitedSigLayer,
            sourceId: _sigSourceId,
            filter: [
              'in',
              ['get', 'SGG_CD'],
              ['literal', visitedSigunguCodes.toList()],
            ],
            fillColor: AppColors.mapVisitedFill.value,
            fillOpacity: 0.85,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [MAP] 에러: $e');
    }
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
