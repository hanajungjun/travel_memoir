import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart'; // TargetPlatform 확인용

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
  // ✂️ [핵심] 안드로이드를 위한 GeoJSON 좌표 단순화 알고리즘
  // =========================================================
  Map<String, dynamic> _simplifyGeoJson(
    String rawJson, {
    double tolerance = 0.005,
  }) {
    final Map<String, dynamic> data = jsonDecode(rawJson);
    final List features = data['features'];

    for (var feature in features) {
      var geometry = feature['geometry'];
      if (geometry == null) continue;

      if (geometry['type'] == 'Polygon') {
        geometry['coordinates'] = _processPolygon(
          geometry['coordinates'],
          tolerance,
        );
      } else if (geometry['type'] == 'MultiPolygon') {
        geometry['coordinates'] = (geometry['coordinates'] as List).map((
          polygon,
        ) {
          return _processPolygon(polygon, tolerance);
        }).toList();
      }
    }
    return data;
  }

  List _processPolygon(List rings, double tolerance) {
    return rings.map((ring) {
      if (ring is! List || ring.length < 3) return ring;

      List simplified = [ring.first];
      for (int i = 1; i < ring.length - 1; i++) {
        var last = simplified.last;
        var curr = ring[i];

        // 두 좌표 사이의 단순 거리를 계산 (위도/경도 차이합)
        double dist = (curr[0] - last[0]).abs() + (curr[1] - last[1]).abs();

        // 설정한 허용치보다 멀리 떨어진 좌표만 리스트에 포함
        if (dist > tolerance) {
          simplified.add(curr);
        }
      }
      simplified.add(ring.last);
      return simplified;
    }).toList();
  }

  // =========================================================
  // 🗺️ 스타일 로드 및 데이터 바인딩
  // =========================================================
  Future<void> _onStyleLoaded(StyleLoadedEventData data) async {
    if (_styleInitialized) return;
    _styleInitialized = true;

    final map = _map;
    if (map == null) return;
    final style = map.style;

    try {
      // 1. 투영법 및 한글화 처리
      await style.setProjection(
        StyleProjection(name: StyleProjectionName.mercator),
      );
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

      // 2. 방문 지역 데이터 가져오기
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final rows = await VisitedRegionService.getVisitedRegionsAll(
        userId: user.id,
      );
      final Set<String> visitedSidoCodes = {};
      final Set<String> visitedSigunguCodes = {};

      for (final row in rows) {
        if (row['type'] == 'sido' && row['sido_cd'] != null)
          visitedSidoCodes.add(row['sido_cd'].toString());
        if (row['type'] == 'city' && row['sgg_cd'] != null)
          visitedSigunguCodes.add(row['sgg_cd'].toString());
      }

      // 3. 시도(Sido) 레이어 적용
      if (visitedSidoCodes.isNotEmpty) {
        final String rawSido = await rootBundle.loadString(_sidoGeoJson);
        String finalSido;

        // 🤖 안드로이드라면 메모리를 위해 다이어트!
        if (defaultTargetPlatform == TargetPlatform.android) {
          debugPrint('🤖 Android detected: Sido 데이터 단순화 적용 중...');
          finalSido = jsonEncode(_simplifyGeoJson(rawSido, tolerance: 0.005));
        } else {
          finalSido = rawSido;
        }

        await _rmLayer(style, _visitedSidoLayer);
        await _rmSource(style, _sidoSourceId);
        await style.addSource(
          GeoJsonSource(id: _sidoSourceId, data: finalSido),
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

      // 4. 시군구(Sig) 레이어 적용 (메모리 폭발 위험 구간)
      if (visitedSigunguCodes.isNotEmpty) {
        final String rawSig = await rootBundle.loadString(_sigGeoJson);
        String finalSig;

        if (defaultTargetPlatform == TargetPlatform.android) {
          debugPrint('🤖 Android detected: Sig 데이터 단순화 적용 중...');
          // 시군구는 데이터가 더 많으므로 확실하게 단순화합니다.
          finalSig = jsonEncode(_simplifyGeoJson(rawSig, tolerance: 0.005));
        } else {
          finalSig = rawSig;
        }

        await _rmLayer(style, _visitedSigLayer);
        await _rmSource(style, _sigSourceId);
        await style.addSource(GeoJsonSource(id: _sigSourceId, data: finalSig));
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
      debugPrint('❌ [MAP] 데이터 로드 중 에러: $e');
    }
  }

  // =========================================================
  // 🖱️ 클릭 및 팝업 로직
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
          String sidoName = props['SIDO_NM']?.toString() ?? '';
          sidoName = sidoName
              .replaceAll('광역시', '')
              .replaceAll('특별', '')
              .replaceAll('자치', '')
              .trim();
          final String sggName = props['SGG_NM']?.toString() ?? '';
          final String code = props['SGG_CD'] ?? props['SIDO_CD'] ?? '';
          _showAiMapPopup(code, sidoName.isNotEmpty ? sidoName : sggName);
        }
      }
    } catch (e) {
      debugPrint('❌ 클릭 쿼리 에러: $e');
    }
  }

  void _showAiMapPopup(String code, String name) async {
    // 1. 이름 정제 ('광주시' -> '광주')
    final searchName = name.replaceAll(RegExp(r'(시|군|구)$'), '').trim();

    // 2. [핵심] 코드를 바탕으로 province 컬럼에 들어갈 정확한 이름 매칭
    String provinceName = "";
    if (code.startsWith('41'))
      provinceName = "경기도";
    else if (code.startsWith('29'))
      provinceName = "광주광역시";
    else if (code.startsWith('48'))
      provinceName = "경상남도";
    else if (code.startsWith('47'))
      provinceName = "경상북도";
    else if (code.startsWith('46'))
      provinceName = "전라남도";
    else if (code.startsWith('45'))
      provinceName = "전라북도"; // 혹은 전북특별자치도
    else if (code.startsWith('44'))
      provinceName = "충청남도";
    else if (code.startsWith('43'))
      provinceName = "충청북도";
    else if (code.startsWith('51'))
      provinceName = "강원특별자치도";
    else if (code.startsWith('50'))
      provinceName = "제주특별자치도";
    else if (code.startsWith('11'))
      provinceName = "서울특별시";
    else if (code.startsWith('26'))
      provinceName = "부산광역시";
    else if (code.startsWith('27'))
      provinceName = "대구광역시";
    else if (code.startsWith('28'))
      provinceName = "인천광역시";
    else if (code.startsWith('30'))
      provinceName = "대전광역시";
    else if (code.startsWith('31'))
      provinceName = "울산광역시";
    else if (code.startsWith('36'))
      provinceName = "세종특별자치시";

    debugPrint(
      '📍 클릭: $name(코드:$code) -> 검색: region($searchName) + province($provinceName)',
    );

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // 3. Supabase 쿼리: region_name과 province를 각각 조건으로 겁니다.
      var query = Supabase.instance.client
          .from('travels')
          .select('map_image_url, region_name, ai_cover_summary, province')
          .eq('user_id', user.id)
          .eq('travel_type', 'domestic')
          .eq('region_name', searchName) // "광주" 정확히 일치
          .not('map_image_url', 'is', null);

      // province 정보가 있으면 조건에 추가 (경기도 광주 vs 광주광역시 완벽 구분)
      if (provinceName.isNotEmpty) {
        query = query.eq('province', provinceName);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        debugPrint('❌ DB에서 해당 기록($provinceName $searchName)을 찾을 수 없음');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$provinceName $name 지역의 기록이 없습니다.')),
          );
        }
        return;
      }

      debugPrint('✅ 이미지 찾음: ${response['map_image_url']}');

      if (!mounted) return;

      // 4. 팝업 실행
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: "AI Map",
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, anim1, anim2) {
          return Center(
            child: AiMapPopup(
              imageUrl: response['map_image_url'],
              regionName: "${response['province']} ${response['region_name']}",
              summary: response['ai_cover_summary'] ?? "기록된 추억이 없습니다.",
            ),
          );
        },
        transitionBuilder: (context, anim1, anim2, child) {
          final curvedValue = Curves.easeOutBack.transform(anim1.value);
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX((1 - curvedValue) * 1.5),
            alignment: Alignment.center,
            child: Opacity(opacity: anim1.value.clamp(0.0, 1.0), child: child),
          );
        },
      );
    } catch (e) {
      debugPrint('❌ 지도 클릭 처리 중 에러: $e');
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
