import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:travel_memoir/services/overseas_travel_service.dart';
import 'package:travel_memoir/core/widgets/ai_map_popup.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';

class GlobalMapPage extends StatefulWidget {
  final bool isReadOnly;

  const GlobalMapPage({super.key, this.isReadOnly = false});

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

  String _toHex(Color color) =>
      '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      key: UniqueKey(),
      styleUri: "mapbox://styles/hanajungjun/cmjztbzby003i01sth91eayzw",
      cameraOptions: CameraOptions(
        center: Point(coordinates: Position(10.0, 20.0)),
        zoom: widget.isReadOnly ? 0.1 : 0.5,
      ),
      // ✅ [제스처 인식기] ReadOnly일 때 터치 우선권을 가져와 좌우 이동이 가능하게 함
      gestureRecognizers: widget.isReadOnly
          ? {Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer())}
          : {
              Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
              Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
            },
      onMapCreated: (map) async {
        _map = map;

        // ✅ [에러 수정 완료] Mapbox SDK 표준 속성명으로 교체
        await map.gestures.updateSettings(
          GesturesSettings(
            pitchEnabled: false,
            rotateEnabled: !widget.isReadOnly,
            scrollEnabled: true, // 이동은 항상 허용
            pinchToZoomEnabled: !widget.isReadOnly, // 요약 모드 시 핀치 줌 방지
            doubleTapToZoomInEnabled: !widget.isReadOnly, // ✅ 더블탭 줌 방지
            doubleTouchToZoomOutEnabled: !widget.isReadOnly, // ✅ 두 손가락 탭 줌 방지
            quickZoomEnabled: !widget.isReadOnly, // ✅ 더블탭 후 드래그 줌 방지
          ),
        );

        if (!mounted) return;
        await map.setBounds(CameraBoundsOptions(minZoom: 0.0, maxZoom: 8.0));
      },
      onStyleLoadedListener: _onStyleLoaded,
      onTapListener: widget.isReadOnly ? null : (context) => _onMapTap(context),
    );
  }

  Future<void> _onMapTap(MapContentGestureContext context) async {
    final map = _map;
    if (map == null) return;
    try {
      final screenCoordinate = await map.pixelForCoordinate(context.point);
      if (!mounted) return;

      final features = await map.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screenCoordinate),
        RenderedQueryOptions(layerIds: [_visitedCountryLayer]),
      );
      if (!mounted) return;

      if (features.isNotEmpty) {
        final props =
            features.first?.queriedFeature.feature['properties'] as Map?;
        if (props != null) {
          final String countryCode =
              props['ISO_A2_EH'] ?? props['iso_a2'] ?? '';
          final String countryName =
              props['NAME'] ?? props['name'] ?? 'overseas_region'.tr();
          if (countryCode.isNotEmpty) {
            _showOverseasAiPopup(countryCode, countryName);
          }
        }
      }
    } catch (e) {
      debugPrint('❌ 해외 클릭 쿼리 에러: $e');
    }
  }

  void _showOverseasAiPopup(String countryCode, String countryName) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final response = await Supabase.instance.client
          .from('travels')
          .select(
            'map_image_url, country_name_ko, country_name_en, ai_cover_summary, is_completed',
          )
          .eq('user_id', user.id)
          .eq('country_code', countryCode)
          .eq('travel_type', 'overseas')
          .order('completed_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (!mounted) return;

      if (response == null) return;

      if (response['is_completed'] == true &&
          response['map_image_url'] != null) {
        _displayPopup(response, countryName);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('trip_in_progress_msg'.tr(args: [countryName])),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ 해외 데이터 조회 에러: $e');
    }
  }

  void _displayPopup(Map<String, dynamic> response, String countryName) {
    if (!mounted) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Global AI Map",
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curvedValue = Curves.easeOutBack.transform(anim1.value);
        final displayRegion =
            (context.locale.languageCode == 'ko'
                ? response['country_name_ko']
                : response['country_name_en']) ??
            countryName;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX((1 - curvedValue) * 1.5),
          alignment: Alignment.bottomCenter,
          child: Opacity(
            opacity: anim1.value.clamp(0.0, 1.0),
            child: AiMapPopup(
              imageUrl: response['map_image_url'],
              regionName: displayRegion,
              summary:
                  response['ai_cover_summary'] ??
                  "remote_memory_placeholder".tr(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData data) async {
    if (_styleInitialized) return;
    _styleInitialized = true;
    final style = _map?.style;
    if (style == null) return;

    try {
      await style.setProjection(
        StyleProjection(name: StyleProjectionName.mercator),
      );
      if (!mounted) return;

      final String lang = context.locale.languageCode;
      final layers = await style.getStyleLayers();
      if (!mounted) return;

      for (var layer in layers) {
        final id = layer?.id;
        if (id != null && (id.contains('label') || id.contains('place'))) {
          try {
            await style.setStyleLayerProperty(
              id,
              'text-field',
              '["get", "name_$lang"]',
            );
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('⚠️ 스타일 설정 에러: $e');
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final response = await Supabase.instance.client
        .from('travels')
        .select('country_code, is_completed, country_name_ko, country_name_en')
        .eq('user_id', user.id)
        .eq('travel_type', 'overseas');

    if (!mounted) return;

    final List<dynamic> travels = response;
    final Set<String> allCodes = {};
    final Set<String> completedCodes = {};
    for (var t in travels) {
      final code = t['country_code']?.toString() ?? '';
      if (code.isNotEmpty) {
        allCodes.add(code);
        if (t['is_completed'] == true) completedCodes.add(code);
      }
    }

    final layers = await style.getStyleLayers();
    if (!mounted) return;

    String? targetBelowId;
    for (var l in layers) {
      if (l != null && (l.id.contains('label') || l.id.contains('symbol'))) {
        targetBelowId = l.id;
        break;
      }
    }

    final worldGeoJson = await rootBundle.loadString(_worldGeoJson);
    if (!mounted) return;

    await _rmLayer(style, _visitedCountryLayer);
    await _rmLayer(style, _borderCountryLayer);
    await _rmSource(style, _worldSourceId);
    if (!mounted) return;

    await style.addSource(
      GeoJsonSource(id: _worldSourceId, data: worldGeoJson),
    );

    final fillLayer = FillLayer(
      id: _visitedCountryLayer,
      sourceId: _worldSourceId,
    );
    if (targetBelowId != null) {
      await style.addLayerAt(fillLayer, LayerPosition(below: targetBelowId));
    } else {
      await style.addLayer(fillLayer);
    }
    if (!mounted) return;

    await style.setStyleLayerProperty(
      _visitedCountryLayer,
      'filter',
      jsonEncode([
        'in',
        ['get', 'ISO_A2_EH'],
        ['literal', allCodes.toList()],
      ]),
    );

    final String doneHex = _toHex(AppColors.mapOverseaVisitedFill);
    final String activeHex = _toHex(
      const Color.fromARGB(255, 211, 28, 34).withOpacity(0.25),
    );

    final dynamic colorExpr = completedCodes.isEmpty
        ? jsonEncode(activeHex)
        : jsonEncode([
            'case',
            [
              'in',
              ['get', 'ISO_A2_EH'],
              ['literal', completedCodes.toList()],
            ],
            doneHex,
            activeHex,
          ]);

    await style.setStyleLayerProperty(
      _visitedCountryLayer,
      'fill-color',
      colorExpr,
    );
    await style.setStyleLayerProperty(
      _visitedCountryLayer,
      'fill-opacity',
      0.7,
    );

    final borderLayer = LineLayer(
      id: _borderCountryLayer,
      sourceId: _worldSourceId,
    );
    if (targetBelowId != null) {
      await style.addLayerAt(
        borderLayer,
        LayerPosition(above: _visitedCountryLayer),
      );
    } else {
      await style.addLayer(borderLayer);
    }
    await style.setStyleLayerProperty(
      _borderCountryLayer,
      'line-color',
      '#333333',
    );
    await style.setStyleLayerProperty(_borderCountryLayer, 'line-width', 0.5);

    if (!mounted) return;

    final pointManager = await _map!.annotations.createPointAnnotationManager();
    Map<String, double>? lastLocation;

    for (final travel in travels) {
      final countryName =
          (context.locale.languageCode == 'ko'
              ? travel['country_name_ko']
              : travel['country_name_en']) ??
          travel['country_name_ko'];
      if (countryName == null) continue;
      try {
        final res = await OverseasTravelService.geocode(query: countryName);
        if (!mounted) return;

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
      } catch (_) {}
    }

    if (!widget.isReadOnly && lastLocation != null) {
      if (!mounted) return;
      await _map!.easeTo(
        CameraOptions(
          center: Point(
            coordinates: Position(lastLocation['lng']!, lastLocation['lat']!),
          ),
          zoom: 1.5,
        ),
        MapAnimationOptions(duration: 1500),
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
