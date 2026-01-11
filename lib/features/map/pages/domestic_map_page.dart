import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';

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

  // ✅ [수정] 에러 나는 setStyleConfigProperty 대신, 모든 레이어를 전수 조사하는 안전한 방식
  Future<void> _localizeMapLabels(StyleManager style) async {
    final String langCode = context.locale.languageCode; // 'ko' 또는 'en'

    try {
      // 1. 현재 지도의 모든 레이어 목록을 가져옵니다.
      final layers = await style.getStyleLayers();

      for (var layer in layers) {
        if (layer == null) continue;
        final String layerId = layer.id;

        // 2. 글자(라벨)와 관련된 레이어만 필터링해서 언어 컬럼을 강제로 변경합니다.
        // 보통 레이어 ID에 'label', 'place', 'poi', 'road' 등이 포함되어 있습니다.
        if (layerId.contains('label') ||
            layerId.contains('place') ||
            layerId.contains('poi') ||
            layerId.contains('road')) {
          try {
            await style.setStyleLayerProperty(
              layerId,
              'text-field',
              '["get", "name_$langCode"]',
            );
          } catch (_) {
            // text-field 속성이 없는 레이어는 무시하고 넘어갑니다.
          }
        }
      }
      debugPrint("✅ 지도의 모든 레이어를 앱 언어($langCode)로 변경 시도 완료");
    } catch (e) {
      debugPrint("❌ 레이어 언어 변경 중 오류 발생: $e");
    }
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

      // ✅ 언어 설정 로직 실행
      await _localizeMapLabels(style);

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final rows = await VisitedRegionService.getVisitedRegionsAll(
        userId: user.id,
      );

      const Map<String, List<String>> majorCityMapping = {
        "41110": ["41111", "41113", "41115", "41117"], // 수원시
        "41130": ["41131", "41133", "41135"], // 성남시
        "41170": ["41171", "41173"], // 안양시
        "41270": ["41271", "41273"], // 안산시
        "41280": ["41281", "41285", "41287"], // 고양시
        "41460": ["41461", "41463", "41465"], // 용인시
        "43110": ["43111", "43112", "43113", "43114"], // 청주시
        "44130": ["44131", "44133"], // 천안시
        "45110": ["45111", "45113"], // 전주시
        "47110": ["47111", "47113"], // 포항시
        "48120": ["48121", "48123", "48125", "48127", "48129"], // 창원시
      };

      final Set<String> visitedSidoCodes = {};
      final Set<String> visitedSigunguCodes = {};

      for (final row in rows) {
        if (row['type'] == 'sido' && row['sido_cd'] != null) {
          visitedSidoCodes.add(row['sido_cd'].toString());
        }
        if (row['type'] == 'city' && row['sgg_cd'] != null) {
          String sggCode = row['sgg_cd'].toString();
          if (majorCityMapping.containsKey(sggCode)) {
            visitedSigunguCodes.addAll(majorCityMapping[sggCode]!);
          } else {
            visitedSigunguCodes.add(sggCode);
          }
        }
      }

      if (visitedSidoCodes.isNotEmpty) {
        final String rawSido = await rootBundle.loadString(_sidoGeoJson);
        await _rmLayer(style, _visitedSidoLayer);
        await _rmSource(style, _sidoSourceId);
        await style.addSource(GeoJsonSource(id: _sidoSourceId, data: rawSido));
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
        final String rawSig = await rootBundle.loadString(_sigGeoJson);
        String finalSig = (defaultTargetPlatform == TargetPlatform.android)
            ? jsonEncode(_simplifyGeoJson(rawSig))
            : rawSig;

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
      debugPrint('❌ [MAP ERROR]: $e');
    }
  }

  // --- 나머지 헬퍼 함수들 (_simplifyGeoJson, _onMapTap 등)은 이전과 동일하게 유지됩니다 ---

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
        geometry['coordinates'] = (geometry['coordinates'] as List)
            .map((polygon) => _processPolygon(polygon, tolerance))
            .toList();
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
        double dist = (curr[0] - last[0]).abs() + (curr[1] - last[1]).abs();
        if (dist > tolerance) simplified.add(curr);
      }
      simplified.add(ring.last);
      return simplified;
    }).toList();
  }

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
      debugPrint('❌ Tap Query Error: $e');
    }
  }

  void _showAiMapPopup(String code, String name) async {
    String searchName = name;
    if (name.contains('시') && name.endsWith('구')) {
      searchName = name.split('시').first;
    } else {
      searchName = name.replaceAll(RegExp(r'(시|군|구)$'), '').trim();
    }

    const provinceCodes = {
      '41': '경기도',
      '11': '서울특별시',
      '26': '부산광역시',
      '27': '대구광역시',
      '28': '인천광역시',
      '29': '광주광역시',
      '30': '대전광역시',
      '31': '울산광역시',
      '36': '세종특별자치시',
      '42': '강원도',
      '51': '강원특별자치도',
      '43': '충청북도',
      '44': '충청남도',
      '45': '전라북도',
      '52': '전북특별자치도',
      '46': '전라남도',
      '47': '경상북도',
      '48': '경상남도',
      '50': '제주특별자치도',
    };

    final String provinceName = provinceCodes[code.substring(0, 2)] ?? "";
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      var query = Supabase.instance.client
          .from('travels')
          .select('map_image_url, region_name, ai_cover_summary, province')
          .eq('user_id', user.id)
          .eq('travel_type', 'domestic')
          .eq('region_name', searchName)
          .not('map_image_url', 'is', null);

      if (provinceName.isNotEmpty) query = query.eq('province', provinceName);

      final response = await query
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('no_record_found'.tr(args: [provinceName, name])),
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: "AI Map",
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, anim1, anim2) {
          final String displayRegion =
              "${response['province'].toString().tr()} ${response['region_name'].toString().tr()}";

          return Center(
            child: AiMapPopup(
              imageUrl: response['map_image_url'],
              regionName: displayRegion,
              summary:
                  response['ai_cover_summary'] ?? "no_memories_recorded".tr(),
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
      debugPrint('❌ Click processing error: $e');
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
