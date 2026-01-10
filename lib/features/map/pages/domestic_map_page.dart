import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart'; // 추가

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
        double dist = (curr[0] - last[0]).abs() + (curr[1] - last[1]).abs();
        if (dist > tolerance) {
          simplified.add(curr);
        }
      }
      simplified.add(ring.last);
      return simplified;
    }).toList();
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

      // ✅ 현재 언어 설정에 따라 Mapbox 필드 결정 (ko -> name_ko, en -> name_en)
      final String lang = context.locale.languageCode;
      final String textFieldName = (lang == 'ko') ? 'name_ko' : 'name_en';

      final layers = await style.getStyleLayers();
      for (var layer in layers) {
        final id = layer?.id;
        if (id != null &&
            (id.contains('label') ||
                id.contains('place') ||
                id.contains('settlement'))) {
          try {
            // ✅ 하드코딩된 "name_ko" 대신 변수 적용
            await style.setStyleLayerProperty(
              id,
              'text-field',
              '["get", "$textFieldName"]',
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
        if (row['type'] == 'sido' && row['sido_cd'] != null)
          visitedSidoCodes.add(row['sido_cd'].toString());
        if (row['type'] == 'city' && row['sgg_cd'] != null)
          visitedSigunguCodes.add(row['sgg_cd'].toString());
      }

      if (visitedSidoCodes.isNotEmpty) {
        final String rawSido = await rootBundle.loadString(_sidoGeoJson);
        String finalSido;
        if (defaultTargetPlatform == TargetPlatform.android) {
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

      if (visitedSigunguCodes.isNotEmpty) {
        final String rawSig = await rootBundle.loadString(_sigGeoJson);
        String finalSig;
        if (defaultTargetPlatform == TargetPlatform.android) {
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
      debugPrint('❌ [MAP] Error: $e');
    }
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
    final searchName = name.replaceAll(RegExp(r'(시|군|구)$'), '').trim();

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
      provinceName = "전라북도";
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

      if (provinceName.isNotEmpty) {
        query = query.eq('province', provinceName);
      }

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
          return Center(
            child: AiMapPopup(
              imageUrl: response['map_image_url'],
              // 💡 provinceName과 region_name은 DB값이므로 그대로 조합하거나, 필요시 provinceName도 tr() 처리할 수 있습니다.
              regionName: "${response['province']} ${response['region_name']}",
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
