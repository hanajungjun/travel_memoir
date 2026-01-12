import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/core/widgets/ai_map_popup.dart';

class DomesticMapPage extends StatefulWidget {
  const DomesticMapPage({super.key});

  @override
  State<DomesticMapPage> createState() => _DomesticMapPageState();
}

class _DomesticMapPageState extends State<DomesticMapPage> {
  MapboxMap? _map;

  static const _sigSourceId = 'korea-sig-source';
  static const _visitedSigLayer = 'visited-sig-layer';
  static const _sigGeoJson = 'assets/geo/processed/korea_sig.geojson';

  static const Map<String, List<String>> majorCityMapping = {
    "41110": ["41111", "41113", "41115", "41117"],
    "41130": ["41131", "41133", "41135"],
    "41170": ["41171", "41173"],
    "41270": ["41271", "41273"],
    "41280": ["41281", "41285", "41287"],
    "41460": ["41461", "41463", "41465"],
    "43110": ["43111", "43112", "43113", "43114"],
    "44130": ["44131", "44133"],
    "45110": ["45111", "45113"],
    "47110": ["47111", "47113"],
    "48120": ["48121", "48123", "48125", "48127", "48129"],
  };

  static const Map<String, String> idToCode = {
    'KR_GG_SEONGNAM': '41130',
    'KR_GB_POHANG': '47110',
    'KR_GB_GYEONGSAN': '47290',
    'KR_GW_SOKCHO': '42210',
  };

  String _toHex(Color color) =>
      '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapWidget(
        key: UniqueKey(),
        styleUri: "mapbox://styles/hanajungjun/cmjztbzby003i01sth91eayzw",
        cameraOptions: CameraOptions(
          center: Point(coordinates: Position(127.8, 36.3)),
          zoom: 5.2,
        ),
        onMapCreated: (map) => _map = map,
        onStyleLoadedListener: (data) => _drawMapData(),
        onTapListener: (context) => _onMapTap(context),
      ),
    );
  }

  Future<void> _localizeLabels(StyleManager style) async {
    final lang = context.locale.languageCode;
    try {
      final layers = await style.getStyleLayers();
      if (!mounted) return; // ✨ 추가: 레이어 목록 가져온 후 상태 체크

      for (var l in layers) {
        if (l != null && (l.id.contains('label') || l.id.contains('place'))) {
          try {
            await style.setStyleLayerProperty(
              l.id,
              'text-field',
              '["get", "name_$lang"]',
            );
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> _drawMapData() async {
    final style = _map?.style;
    if (style == null) return;

    try {
      await style.setProjection(
        StyleProjection(name: StyleProjectionName.mercator),
      );
      if (!mounted) return; // ✨ 추가

      await _localizeLabels(style);
      if (!mounted) return; // ✨ 추가

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final travels = await Supabase.instance.client
          .from('travels')
          .select('region_id, is_completed')
          .eq('user_id', user.id)
          .eq('travel_type', 'domestic');

      if (!mounted) return; // ✨ 추가: DB 조회 후 위젯이 사라졌으면 중단

      final Set<String> allSgg = {};
      final Set<String> completedSgg = {};

      for (var t in travels) {
        String regId = t['region_id']?.toString() ?? '';
        String? code = idToCode[regId];
        if (code == null) continue;

        bool done = t['is_completed'] == true;
        allSgg.add(code);
        if (done) completedSgg.add(code);

        if (majorCityMapping.containsKey(code)) {
          allSgg.addAll(majorCityMapping[code]!);
          if (done) completedSgg.addAll(majorCityMapping[code]!);
        }
      }

      final String rawSig = await rootBundle.loadString(_sigGeoJson);
      if (!mounted) return;

      await _rmLayer(style, _visitedSigLayer);
      await _rmSource(style, _sigSourceId);
      if (!mounted) return; // ✨ 추가

      await style.addSource(GeoJsonSource(id: _sigSourceId, data: rawSig));

      final fillLayer = FillLayer(id: _visitedSigLayer, sourceId: _sigSourceId);
      await style.addLayer(fillLayer);
      if (!mounted) return; // ✨ 추가

      final String doneColor = _toHex(AppColors.mapVisitedFill);
      final String activeColor = _toHex(
        const Color.fromARGB(244, 227, 12, 26).withOpacity(0.3),
      );

      await style.setStyleLayerProperty(
        _visitedSigLayer,
        'filter',
        jsonEncode([
          'in',
          ['get', 'SGG_CD'],
          ['literal', allSgg.toList()],
        ]),
      );

      final dynamic colorExpr = completedSgg.isEmpty
          ? jsonEncode(activeColor)
          : jsonEncode([
              'case',
              [
                'in',
                ['get', 'SGG_CD'],
                ['literal', completedSgg.toList()],
              ],
              doneColor,
              activeColor,
            ]);

      await style.setStyleLayerProperty(
        _visitedSigLayer,
        'fill-color',
        colorExpr,
      );
      await style.setStyleLayerProperty(_visitedSigLayer, 'fill-opacity', 0.8);

      debugPrint("🚀 국내지도 색상 구분 완료!");
    } catch (e) {
      debugPrint('❌ 에러: $e');
    }
  }

  Future<void> _onMapTap(MapContentGestureContext context) async {
    final map = _map;
    if (map == null) return;
    try {
      final screenCoordinate = await map.pixelForCoordinate(context.point);
      final features = await map.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screenCoordinate),
        RenderedQueryOptions(layerIds: [_visitedSigLayer]),
      );
      if (!mounted) return; // ✨ 추가: 맵 쿼리 후 체크

      if (features.isNotEmpty) {
        final props =
            features.first?.queriedFeature.feature['properties'] as Map?;
        if (props != null) {
          String sggCode = props['SGG_CD']?.toString() ?? '';
          String lookup = sggCode;
          majorCityMapping.forEach((parent, children) {
            if (children.contains(sggCode)) lookup = parent;
          });

          final codeToId = idToCode.map((k, v) => MapEntry(v, k));
          String? regId = codeToId[lookup];

          if (regId != null) _handlePopup(regId);
        }
      }
    } catch (_) {}
  }

  void _handlePopup(String regId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final res = await Supabase.instance.client
        .from('travels')
        .select()
        .eq('user_id', user.id)
        .eq('region_id', regId)
        .maybeSingle();

    if (!mounted) return; // ✨ 기존 유지

    if (res != null && res['is_completed'] == true) {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: "AI Map",
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, anim1, anim2) => Center(
          child: AiMapPopup(
            imageUrl: res['map_image_url'],
            regionName:
                "${res['province'].toString().tr()} ${res['region_name'].toString().tr()}",
            summary: res['ai_cover_summary'] ?? "no_memories_recorded".tr(),
          ),
        ),
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
