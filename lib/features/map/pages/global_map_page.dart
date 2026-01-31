import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/storage_urls.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/core/widgets/ai_map_popup.dart';

class DetailedMapConfig {
  final String countryCode;
  final String geoJsonPath;
  final String sourceId;
  final String layerId;
  final String labelLayerId;

  DetailedMapConfig({
    required this.countryCode,
    required this.geoJsonPath,
    required this.sourceId,
    required this.layerId,
    required this.labelLayerId,
  });
}

class GlobalMapPage extends StatefulWidget {
  final bool isReadOnly;
  final bool showLastTravelFocus;
  const GlobalMapPage({
    super.key,
    this.isReadOnly = false,
    this.showLastTravelFocus = false,
  });

  @override
  State<GlobalMapPage> createState() => GlobalMapPageState();
}

class GlobalMapPageState extends State<GlobalMapPage>
    with AutomaticKeepAliveClientMixin {
  MapboxMap? _map;
  bool _init = false;
  bool _ready = false;

  @override
  bool get wantKeepAlive => true;

  static const _worldSource = 'world-source';
  static const _worldFill = 'world-fill';
  static const _worldGeo = 'assets/geo/processed/world_countries.geojson';

  final List<DetailedMapConfig> _supportedDetailedMaps = [
    DetailedMapConfig(
      countryCode: 'US',
      geoJsonPath: 'assets/geo/processed/usa_states_standard.json',
      sourceId: 'usa-source',
      layerId: 'usa-fill',
      labelLayerId: 'state-label',
    ),
    DetailedMapConfig(
      countryCode: 'JP',
      geoJsonPath: 'assets/geo/processed/japan_prefectures.json',
      sourceId: 'japan-source',
      layerId: 'japan-fill',
      labelLayerId: 'settlement-label',
    ),
    DetailedMapConfig(
      countryCode: 'IT',
      geoJsonPath: 'assets/geo/processed/italy_regions.json',
      sourceId: 'italy-source',
      layerId: 'italy-fill',
      labelLayerId: 'settlement-label',
    ),
  ];

  Set<String> _purchasedMapIds = {};

  bool _hasAccess(String countryCode) =>
      _purchasedMapIds.contains(countryCode.toLowerCase());

  String _hex(Color c) =>
      '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  Future<void> _updateMapGestures() async {
    if (_map == null) return;
    try {
      await _map!.gestures.updateSettings(
        widget.isReadOnly
            ? GesturesSettings(
                scrollEnabled: true,
                pinchToZoomEnabled: false,
                doubleTapToZoomInEnabled: false,
                doubleTouchToZoomOutEnabled: false,
                quickZoomEnabled: false,
                rotateEnabled: false,
                pitchEnabled: false,
              )
            : GesturesSettings(
                scrollEnabled: true,
                pinchToZoomEnabled: true,
                rotateEnabled: true,
                pitchEnabled: true,
              ),
      );
    } catch (_) {}
  }

  @override
  void didUpdateWidget(GlobalMapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isReadOnly != widget.isReadOnly) {
      _updateMapGestures();
    }
  }

  Future<void> refreshData() async {
    if (_map == null) return;
    await _drawAll();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        MapWidget(
          styleUri: "mapbox://styles/hanajungjun/cmjztbzby003i01sth91eayzw",
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
          cameraOptions: CameraOptions(
            center: Point(coordinates: Position(10, 20)),
            zoom: 1.3,
          ),
          onMapCreated: (map) async {
            _map = map;
            try {
              await map.setBounds(
                CameraBoundsOptions(minZoom: 0.8, maxZoom: 6.0),
              );
            } catch (_) {}
          },
          onStyleLoadedListener: _onStyleLoaded,
          onTapListener: widget.isReadOnly ? null : _onMapTap,
        ),
        if (!_ready)
          const ColoredBox(
            color: Colors.white,
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    if (_init || _map == null) return;
    _init = true;

    await WidgetsBinding.instance.endOfFrame;
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted || _map == null) return;

    await _updateMapGestures();

    try {
      await _map!.style.setProjection(
        StyleProjection(name: StyleProjectionName.mercator),
      );
    } catch (_) {}

    await _localizeLabels();
    await _loadUserMapAccess();
    await _drawAll();

    // 🎯 애니메이션 없이 위치만 잡아주도록 수정됨
    if (widget.showLastTravelFocus) {
      await _focusOnLastTravel();
    }

    _safeSetState(() => _ready = true);
  }

  Future<void> _loadUserMapAccess() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('active_maps')
          .eq('auth_uid', user.id)
          .maybeSingle();
      final List activeList = (res?['active_maps'] as List?) ?? [];
      _safeSetState(() {
        _purchasedMapIds = activeList
            .map((e) => e.toString().toLowerCase())
            .toSet();
      });
    } catch (_) {}
  }

  Future<void> _drawAll() async {
    final map = _map;
    if (map == null || !mounted) return;

    final style = map.style;
    if (style == null) return;

    try {
      final travels = await Supabase.instance.client
          .from('travels')
          .select('country_code, region_name, is_completed, travel_type')
          .eq('user_id', Supabase.instance.client.auth.currentUser!.id);

      final Set<String> visitedCountries = {};
      final Set<String> completedCountries = {};
      final Map<String, Set<String>> visitedRegions = {};
      final Map<String, Set<String>> completedRegions = {};

      for (var t in (travels as List)) {
        final code = t['country_code']?.toString().toUpperCase() ?? '';
        if (code.isEmpty) continue;

        visitedCountries.add(code);
        if (t['is_completed'] == true) completedCountries.add(code);

        final rn = t['region_name']?.toString();
        if (rn != null) {
          visitedRegions.putIfAbsent(code, () => {}).add(rn.toUpperCase());
          if (t['is_completed'] == true)
            completedRegions.putIfAbsent(code, () => {}).add(rn.toUpperCase());
        }
      }

      final worldJson = await rootBundle.loadString(_worldGeo);

      await _rm(style, _worldFill, _worldSource);

      if (!(await style.styleSourceExists(_worldSource))) {
        await style.addSource(GeoJsonSource(id: _worldSource, data: worldJson));
      }

      if (!(await style.styleLayerExists(_worldFill))) {
        await style.addLayer(FillLayer(id: _worldFill, sourceId: _worldSource));
      }

      final worldFilterExpr = [
        'any',
        [
          'in',
          ['get', 'ISO_A2_EH'],
          ['literal', visitedCountries.toList()],
        ],
        [
          'in',
          ['get', 'iso_a2'],
          ['literal', visitedCountries.toList()],
        ],
        [
          'in',
          ['get', 'ISO_A2'],
          ['literal', visitedCountries.toList()],
        ],
      ];
      await style.setStyleLayerProperty(_worldFill, 'filter', worldFilterExpr);

      final subMapBaseHex = _hex(
        const Color.fromARGB(255, 216, 219, 221).withOpacity(0.12),
      );
      final doneHex = _hex(AppColors.mapOverseaVisitedFill);
      final activeHex = _hex(
        const Color.fromARGB(255, 144, 73, 77).withOpacity(0.25),
      );

      final List<dynamic> worldColorExpr = ['case'];
      for (var config in _supportedDetailedMaps) {
        worldColorExpr.add([
          'all',
          [
            'any',
            [
              '==',
              ['get', 'ISO_A2'],
              config.countryCode,
            ],
            [
              '==',
              ['get', 'iso_a2'],
              config.countryCode,
            ],
          ],
          _hasAccess(config.countryCode),
        ]);
        worldColorExpr.add(subMapBaseHex);
      }
      worldColorExpr.addAll([
        [
          'any',
          [
            'in',
            ['get', 'ISO_A2_EH'],
            ['literal', completedCountries.toList()],
          ],
          [
            'in',
            ['get', 'iso_a2'],
            ['literal', completedCountries.toList()],
          ],
          [
            'in',
            ['get', 'ISO_A2'],
            ['literal', completedCountries.toList()],
          ],
        ],
        doneHex,
        activeHex,
      ]);

      await style.setStyleLayerProperty(
        _worldFill,
        'fill-color',
        worldColorExpr,
      );
      await style.setStyleLayerProperty(_worldFill, 'fill-opacity', 0.7);

      for (var config in _supportedDetailedMaps) {
        if (_hasAccess(config.countryCode)) {
          await Future.delayed(const Duration(milliseconds: 50));
          await _drawSubMap(
            style,
            config,
            visitedRegions[config.countryCode] ?? {},
            completedRegions[config.countryCode] ?? {},
            doneHex,
          );
        }
      }
    } catch (e) {
      debugPrint("⚠️ _drawAll 안전 예외 처리: $e");
    }
  }

  Future<void> _drawSubMap(
    StyleManager style,
    DetailedMapConfig config,
    Set<String> visited,
    Set<String> completed,
    String doneHex,
  ) async {
    try {
      final json = await rootBundle.loadString(config.geoJsonPath);
      await _rm(style, config.layerId, config.sourceId);

      if (!(await style.styleSourceExists(config.sourceId))) {
        await style.addSource(GeoJsonSource(id: config.sourceId, data: json));
      }

      if (!(await style.styleLayerExists(config.layerId))) {
        await style.addLayer(
          FillLayer(id: config.layerId, sourceId: config.sourceId),
        );
      }

      if (await style.styleLayerExists(config.labelLayerId)) {
        await style.moveStyleLayer(
          config.layerId,
          LayerPosition(below: config.labelLayerId),
        );
      }

      await style.setStyleLayerProperty(config.layerId, 'filter', [
        'in',
        [
          'upcase',
          ['get', 'NAME'],
        ],
        ['literal', visited.toList()],
      ]);
      await style.setStyleLayerProperty(config.layerId, 'fill-color', [
        'case',
        [
          'in',
          [
            'upcase',
            ['get', 'NAME'],
          ],
          ['literal', completed.toList()],
        ],
        doneHex,
        _hex(const Color.fromARGB(255, 228, 176, 180).withOpacity(0.4)),
      ]);
      await style.setStyleLayerProperty(config.layerId, 'fill-opacity', 0.45);
    } catch (e) {
      debugPrint('❌ Error drawing ${config.countryCode}: $e');
    }
  }

  Future<void> _onMapTap(MapContentGestureContext ctx) async {
    if (_map == null) return;
    final screen = await _map!.pixelForCoordinate(ctx.point);
    for (var config in _supportedDetailedMaps) {
      if (_hasAccess(config.countryCode)) {
        final features = await _map!.queryRenderedFeatures(
          RenderedQueryGeometry.fromScreenCoordinate(screen),
          RenderedQueryOptions(layerIds: [config.layerId]),
        );
        if (features.isNotEmpty) {
          final props =
              features.first?.queriedFeature.feature['properties'] as Map?;
          final regionName = (props?['NAME'] ?? props?['name'])?.toString();
          if (regionName != null) {
            _showPopup(
              countryCode: config.countryCode,
              regionName: regionName.toUpperCase(),
            );
            return;
          }
        }
      }
    }
    final world = await _map!.queryRenderedFeatures(
      RenderedQueryGeometry.fromScreenCoordinate(screen),
      RenderedQueryOptions(layerIds: [_worldFill]),
    );
    if (world.isEmpty) return;
    final props = world.first?.queriedFeature.feature['properties'] as Map?;
    final code = (props?['ISO_A2'] ?? props?['iso_a2'] ?? props?['ISO_A2_EH'])
        ?.toString()
        .toUpperCase();
    if (code != null) {
      final isKo = context.locale.languageCode == 'ko';
      final name =
          (isKo
                  ? (props?['NAME_KO'] ?? props?['NAME'])
                  : (props?['NAME'] ?? props?['NAME_KO']))
              ?.toString();
      _showPopup(countryCode: code, regionName: name ?? code);
    }
  }

  void _showPopup({
    required String countryCode,
    required String regionName,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    bool isDetailed = _hasAccess(countryCode);
    var query = Supabase.instance.client
        .from('travels')
        .select('map_image_url, ai_cover_summary')
        .eq('user_id', user.id)
        .eq('country_code', countryCode);
    if (isDetailed) query = query.eq('region_name', regionName);
    final res = await query
        .eq('is_completed', true)
        .order('completed_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return;
    final rawPath = res['map_image_url']?.toString() ?? '';

    String finalUrl = (countryCode == 'US' && _hasAccess('US'))
        ? StorageUrls.usaMapFromPath(rawPath)
        : StorageUrls.globalMapFromPath('${countryCode.toUpperCase()}.png');

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Popup',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (_, anim, __, ___) => Opacity(
        opacity: anim.value,
        child: AiMapPopup(
          imageUrl: finalUrl,
          regionName: regionName,
          summary: res['ai_cover_summary'] ?? '',
        ),
      ),
    );
  }

  Future<void> _localizeLabels() async {
    final map = _map;
    if (map == null) return;
    final lang = context.locale.languageCode;
    final layers = [
      'country-label',
      'settlement-label',
      'state-label',
      'poi-label',
    ];
    for (final id in layers) {
      try {
        if (await map.style.styleLayerExists(id)) {
          await map.style.setStyleLayerProperty(
            id,
            'text-field',
            lang == 'ko' ? ['get', 'name_ko'] : ['get', 'name_en'],
          );
        }
      } catch (_) {}
    }
  }

  Future<void> _focusOnLastTravel() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _map == null) return;

    try {
      final lastTravel = await Supabase.instance.client
          .from('travels')
          .select('region_lat, region_lng, country_lat, country_lng')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (lastTravel != null && mounted && _map != null) {
        double? lat =
            (lastTravel['region_lat'] as num? ??
                    lastTravel['country_lat'] as num?)
                ?.toDouble();
        double? lng =
            (lastTravel['region_lng'] as num? ??
                    lastTravel['country_lng'] as num?)
                ?.toDouble();

        if (lat != null && lng != null) {
          double focusZoom = 3.5;
          if (lat < -60) {
            focusZoom = 0.5; // 멀리서 봐야 주변 바다가 보여서 덜 빨갛게 보입니다.
          }
          // 🚀 flyTo 대신 setCamera를 사용하여 채널 에러 원천 차단
          _map!.setCamera(
            CameraOptions(
              center: Point(coordinates: Position(lng, lat)),
              zoom: focusZoom,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("⚠️ _focusOnLastTravel Error: $e");
    }
  }

  Future<void> _rm(StyleManager s, String layer, String source) async {
    try {
      if (await s.styleLayerExists(layer)) await s.removeStyleLayer(layer);
    } catch (_) {}
    try {
      if (await s.styleSourceExists(source)) await s.removeStyleSource(source);
    } catch (_) {}
  }
}
