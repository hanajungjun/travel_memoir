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
          styleUri: "mapbox://styles/hanajungjun/cmjztbzby003i01sth91eayzw",
          cameraOptions: CameraOptions(
            center: Point(coordinates: Position(10.0, 20.0)),
            zoom: 1.2, // ✅ 지도 크기 복구
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

  // =========================
  // STYLE LOADED
  // =========================
  Future<void> _onStyleLoaded(StyleLoadedEventData data) async {
    if (_styleInitialized || _map == null) return;

    _styleInitialized = true;

    // ✅ 지도 먼저 표시
    _safeSetState(() => _isReadyToDisplay = true);

    // ✅ 무거운 작업은 뒤에서
    Future.microtask(() => _drawWorldLayers());
  }

  // =========================
  // WORLD LAYERS
  // =========================
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
      // 1. projection
      await safeAction(
        () => style.setProjection(
          StyleProjection(name: StyleProjectionName.mercator),
        ),
      );

      // 2. label language
      try {
        final lang = context.locale.languageCode;
        final layers = await style.getStyleLayers();
        for (var l in layers) {
          final id = l?.id;
          if (id != null && (id.contains('label') || id.contains('place'))) {
            if (await style.styleLayerExists(id)) {
              await style.setStyleLayerProperty(
                id,
                'text-field',
                '["get", "name_$lang"]',
              );
            }
          }
        }
      } catch (_) {}

      // 3. supabase
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final travels = await Supabase.instance.client
          .from('travels')
          .select(
            'country_code, is_completed, country_name_ko, country_name_en',
          )
          .eq('user_id', user.id)
          .eq('travel_type', 'overseas');

      if (!mounted) return;

      final Set<String> allCodes = {};
      final Set<String> completedCodes = {};

      for (var t in travels) {
        final code = t['country_code']?.toString();
        if (code != null && code.isNotEmpty) {
          allCodes.add(code);
          if (t['is_completed'] == true) completedCodes.add(code);
        }
      }

      // 4. geojson + layers
      final worldGeoJson = await rootBundle.loadString(_worldGeoJson);

      await safeAction(() async {
        await _rmLayer(style, _visitedCountryLayer);
        await _rmLayer(style, _borderCountryLayer);
        await _rmSource(style, _worldSourceId);

        await style.addSource(
          GeoJsonSource(id: _worldSourceId, data: worldGeoJson),
        );

        final fillLayer = FillLayer(
          id: _visitedCountryLayer,
          sourceId: _worldSourceId,
        );
        await style.addLayer(fillLayer);

        await style.setStyleLayerProperty(
          _visitedCountryLayer,
          'filter',
          jsonEncode([
            'in',
            ['get', 'ISO_A2_EH'],
            ['literal', allCodes.toList()],
          ]),
        );

        final doneHex = _toHex(AppColors.mapOverseaVisitedFill);
        final activeHex = _toHex(
          const Color.fromARGB(255, 211, 28, 34).withOpacity(0.25),
        );

        final colorExpr = completedCodes.isEmpty
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

      // 5. marker + 자동 포커스 복구
      final pointManager = await _map!.annotations
          .createPointAnnotationManager();

      Map<String, dynamic>? lastTravel;

      for (final t in travels) {
        final name = context.locale.languageCode == 'ko'
            ? t['country_name_ko']
            : t['country_name_en'];

        if (name == null) continue;
        lastTravel ??= t;

        try {
          final geo = await OverseasTravelService.geocode(query: name);
          if (geo != null) {
            await pointManager.create(
              PointAnnotationOptions(
                geometry: Point(coordinates: Position(geo['lng'], geo['lat'])),
                iconImage: 'marker-15',
                iconSize: 1.6,
              ),
            );
          }
        } catch (_) {}
      }

      // ✅ 자동 포커스 (원래 동작 복구)
      if (!widget.isReadOnly && lastTravel != null && mounted) {
        final focusName = context.locale.languageCode == 'ko'
            ? lastTravel['country_name_ko']
            : lastTravel['country_name_en'];

        if (focusName != null) {
          try {
            final geo = await OverseasTravelService.geocode(query: focusName);
            if (geo != null && mounted) {
              await _map!.easeTo(
                CameraOptions(
                  center: Point(coordinates: Position(geo['lng'], geo['lat'])),
                  zoom: 1.5,
                ),
                MapAnimationOptions(duration: 1200),
              );
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('❌ world map error: $e');
    }
  }

  // =========================
  // TAP
  // =========================
  Future<void> _onMapTap(MapContentGestureContext context) async {
    if (_map == null) return;

    final screen = await _map!.pixelForCoordinate(context.point);
    final features = await _map!.queryRenderedFeatures(
      RenderedQueryGeometry.fromScreenCoordinate(screen),
      RenderedQueryOptions(layerIds: [_visitedCountryLayer]),
    );

    if (features.isEmpty) return;

    final props = features.first?.queriedFeature.feature['properties'] as Map?;
    if (props == null) return;

    final code = props['ISO_A2_EH'] ?? props['iso_a2'];
    final name = props['NAME'] ?? props['name'];

    if (code != null && name != null) {
      _showOverseasAiPopup(code, name);
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
        .eq('country_code', countryCode)
        .eq('travel_type', 'overseas')
        .order('completed_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (res == null || res['is_completed'] != true) return;

    final displayName = context.locale.languageCode == 'ko'
        ? res['country_name_ko']
        : res['country_name_en'];

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Global AI Map',
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (_, anim, __, ___) {
        return Opacity(
          opacity: anim.value,
          child: AiMapPopup(
            imageUrl: res['map_image_url'],
            regionName: displayName ?? countryName,
            summary:
                res['ai_cover_summary'] ?? 'remote_memory_placeholder'.tr(),
          ),
        );
      },
    );
  }

  Future<void> _rmLayer(StyleManager style, String id) async {
    if (await style.styleLayerExists(id)) {
      await style.removeStyleLayer(id);
    }
  }

  Future<void> _rmSource(StyleManager style, String id) async {
    if (await style.styleSourceExists(id)) {
      await style.removeStyleSource(id);
    }
  }
}
