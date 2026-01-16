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
  bool _isReadyToDisplay = false;

  final GlobalKey _mapKey = GlobalKey();

  static const _worldSourceId = 'world-country-source';
  static const _visitedCountryLayer = 'visited-country-layer';
  static const _borderCountryLayer = 'border-country-layer';
  static const _worldGeoJson = 'assets/geo/processed/world_countries.geojson';

  String _toHex(Color color) =>
      '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapWidget(
          key: _mapKey,
          styleUri: "mapbox://styles/hanajungjun/cmjztbzby003i01sth91eayzw",
          cameraOptions: CameraOptions(
            center: Point(coordinates: Position(10.0, 20.0)),
            zoom: 1.2,
          ),
          gestureRecognizers: widget.isReadOnly
              ? {
                  Factory<EagerGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                }
              : {
                  Factory<ScaleGestureRecognizer>(
                    () => ScaleGestureRecognizer(),
                  ),
                  Factory<EagerGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                },
          onMapCreated: (map) async {
            _map = map;
            try {
              await map.gestures.updateSettings(
                GesturesSettings(
                  pitchEnabled: false,
                  rotateEnabled: !widget.isReadOnly,
                  scrollEnabled: true,
                  pinchToZoomEnabled: !widget.isReadOnly,
                  doubleTapToZoomInEnabled: !widget.isReadOnly,
                  doubleTouchToZoomOutEnabled: !widget.isReadOnly,
                  quickZoomEnabled: !widget.isReadOnly,
                ),
              );
              await map.setBounds(
                CameraBoundsOptions(minZoom: 0.0, maxZoom: 8.0),
              );
            } catch (_) {}
          },
          onStyleLoadedListener: _onStyleLoaded,
          onTapListener: widget.isReadOnly ? null : _onMapTap,
        ),
        if (!_isReadyToDisplay)
          Container(
            color: Colors.white,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData data) async {
    if (_styleInitialized || _map == null) return;
    _styleInitialized = true;

    // 🎯 [에러 수정] 직접 localizeLabels를 호출하는 대신,
    // 우리가 성공했던 '레이어 속성 직접 수정' 방식으로 현지화를 처리합니다.
    await _localizeMapLabels();

    _safeSetState(() => _isReadyToDisplay = true);
    Future.microtask(() => _drawWorldLayers());
  }

  // ✅ [복구] 다른 페이지에서 성공했던 라벨 현지화 로직
  Future<void> _localizeMapLabels() async {
    if (_map == null) return;
    try {
      final String lang = context.locale.languageCode; // 'ko' 또는 'en'
      // 맵박스 기본 스타일의 텍스트 필드를 현재 언어 설정으로 강제 전환
      final String textFieldValue = lang == 'ko' ? '{name_ko}' : '{name_en}';

      // 주요 텍스트 레이어 ID 리스트 (국가명, 도시명 등)
      final labelLayers = [
        'country-label',
        'settlement-label',
        'state-label',
        'water-point-label',
        'poi-label',
      ];

      for (var layerId in labelLayers) {
        if (await _map!.style.styleLayerExists(layerId)) {
          await _map!.style.setStyleLayerProperty(
            layerId,
            'text-field',
            lang == 'ko' ? ['get', 'name_ko'] : ['get', 'name_en'],
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ Label localization failed: $e');
    }
  }

  Future<void> _drawWorldLayers() async {
    if (!mounted || _map == null) return;
    final style = _map!.style;

    Future<void> safeAction(Future<void> Function() action) async {
      for (int i = 0; i < 3; i++) {
        try {
          await action();
          return;
        } catch (e) {
          if (e is PlatformException && e.code == 'channel-error') {
            await Future.delayed(Duration(milliseconds: 300 * (i + 1)));
            if (!mounted) return;
          } else {
            rethrow;
          }
        }
      }
    }

    try {
      await safeAction(
        () => style.setProjection(
          StyleProjection(name: StyleProjectionName.mercator),
        ),
      );

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final travels = await Supabase.instance.client
          .from('travels')
          .select(
            'country_code, is_completed, country_name_ko, country_name_en, country_lat, country_lng',
          )
          .eq('user_id', user.id)
          .eq('travel_type', 'overseas');

      if (!mounted) return;

      final Set<String> allCodes = {};
      final Set<String> completedCodes = {};

      for (var t in travels) {
        final code = t['country_code']?.toString().toUpperCase();
        if (code != null && code.isNotEmpty) {
          allCodes.add(code);
          if (t['is_completed'] == true) completedCodes.add(code);
        }
      }

      final worldGeoJson = await rootBundle.loadString(_worldGeoJson);

      await safeAction(() async {
        await _rmLayer(style, _visitedCountryLayer);
        await _rmLayer(style, _borderCountryLayer);
        await _rmSource(style, _worldSourceId);

        await style.addSource(
          GeoJsonSource(id: _worldSourceId, data: worldGeoJson),
        );

        final filterExpr = [
          'any',
          [
            'in',
            ['get', 'ISO_A2_EH'],
            ['literal', allCodes.toList()],
          ],
          [
            'in',
            ['get', 'iso_a2'],
            ['literal', allCodes.toList()],
          ],
          [
            'in',
            ['get', 'ISO_A2'],
            ['literal', allCodes.toList()],
          ],
        ];

        final fillLayer = FillLayer(
          id: _visitedCountryLayer,
          sourceId: _worldSourceId,
        );
        await style.addLayer(fillLayer);
        await style.setStyleLayerProperty(
          _visitedCountryLayer,
          'filter',
          filterExpr,
        );

        final doneHex = _toHex(AppColors.mapOverseaVisitedFill);
        final activeHex = _toHex(
          const Color.fromARGB(255, 211, 28, 34).withOpacity(0.25),
        );

        final dynamic colorExpr = completedCodes.isEmpty
            ? activeHex
            : [
                'case',
                [
                  'any',
                  [
                    'in',
                    ['get', 'ISO_A2_EH'],
                    ['literal', completedCodes.toList()],
                  ],
                  [
                    'in',
                    ['get', 'iso_a2'],
                    ['literal', completedCodes.toList()],
                  ],
                ],
                doneHex,
                activeHex,
              ];

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
        await style.addLayer(borderLayer);
        await style.setStyleLayerProperty(
          _borderCountryLayer,
          'line-color',
          '#333333',
        );
        await style.setStyleLayerProperty(
          _borderCountryLayer,
          'line-width',
          0.5,
        );
      });

      final pointManager = await _map!.annotations
          .createPointAnnotationManager();
      for (final t in travels) {
        double? lat = (t['country_lat'] as num?)?.toDouble();
        double? lng = (t['country_lng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          await pointManager.create(
            PointAnnotationOptions(
              geometry: Point(coordinates: Position(lng, lat)),
              iconImage: 'marker-15',
              iconSize: 1.6,
            ),
          );
        }
      }

      if (!widget.isReadOnly && mounted && travels.isNotEmpty) {
        final lastTravel = travels.last;
        double? targetLat = (lastTravel['country_lat'] as num?)?.toDouble();
        double? targetLng = (lastTravel['country_lng'] as num?)?.toDouble();
        if (targetLat != null && targetLng != null && mounted) {
          await _map!.easeTo(
            CameraOptions(
              center: Point(coordinates: Position(targetLng, targetLat)),
              zoom: 1.5,
            ),
            MapAnimationOptions(duration: 1200),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ world map error: $e');
    }
  }

  Future<void> _onMapTap(MapContentGestureContext mapContext) async {
    if (_map == null) return;
    final screen = await _map!.pixelForCoordinate(mapContext.point);
    final features = await _map!.queryRenderedFeatures(
      RenderedQueryGeometry.fromScreenCoordinate(screen),
      RenderedQueryOptions(layerIds: [_visitedCountryLayer]),
    );
    if (features.isEmpty) return;

    final props = features.first?.queriedFeature.feature['properties'] as Map?;
    if (props == null) return;

    final bool isKo = context.locale.languageCode == 'ko';
    final code = props['ISO_A2_EH'] ?? props['iso_a2'] ?? props['ISO_A2'];
    final name = isKo
        ? (props['NAME_KO'] ?? props['NAME'] ?? props['name'])
        : (props['NAME'] ?? props['name'] ?? props['NAME_KO']);

    if (code != null && name != null) {
      _showOverseasAiPopup(code.toString(), name.toString());
    }
  }

  void _showOverseasAiPopup(String countryCode, String countryName) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final res = await Supabase.instance.client
        .from('travels')
        .select(
          'map_image_url, country_name_ko, country_name_en, ai_cover_summary, is_completed',
        )
        .eq('user_id', user.id)
        .eq('country_code', countryCode.toUpperCase())
        .eq('travel_type', 'overseas')
        .order('completed_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (res == null || res['is_completed'] != true) return;

    final String? dbName = context.locale.languageCode == 'ko'
        ? res['country_name_ko']
        : res['country_name_en'];

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Global AI Map',
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (_, anim, __, ___) => Opacity(
        opacity: anim.value,
        child: AiMapPopup(
          imageUrl: res['map_image_url'],
          regionName: dbName ?? countryName,
          summary: res['ai_cover_summary'] ?? 'remote_memory_placeholder'.tr(),
        ),
      ),
    );
  }

  Future<void> _rmLayer(StyleManager style, String id) async {
    if (await style.styleLayerExists(id)) await style.removeStyleLayer(id);
  }

  Future<void> _rmSource(StyleManager style, String id) async {
    if (await style.styleSourceExists(id)) await style.removeStyleSource(id);
  }
}
