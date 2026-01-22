import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/core/widgets/ai_map_popup.dart';

class GlobalMapPage extends StatefulWidget {
  final bool isReadOnly;
  final bool showLastTravelFocus;
  const GlobalMapPage({
    super.key,
    this.isReadOnly = false,
    this.showLastTravelFocus = false,
  });

  @override
  State<GlobalMapPage> createState() => GlobalMapPageState(); // 외부 호출을 위해 public 설정
}

class GlobalMapPageState extends State<GlobalMapPage>
    with AutomaticKeepAliveClientMixin {
  MapboxMap? _map;
  bool _init = false;
  bool _ready = false;

  @override
  bool get wantKeepAlive => true; // 탭 전환 시 지도 상태 유지

  static const _worldSource = 'world-source';
  static const _worldFill = 'world-fill';
  static const _worldGeo = 'assets/geo/processed/world_countries.geojson';

  static const _usaSource = 'usa-source';
  static const _usaFill = 'usa-fill';
  static const _usaGeo = 'assets/geo/processed/usa_states_standard.json';

  bool _hasUsaAccess = false;

  String _hex(Color c) =>
      '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  // 외부(Pager)에서 호출하여 지도 데이터만 다시 그리는 함수
  Future<void> refreshData() async {
    if (_map == null) return;
    await _drawAll();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // mixin 사용 시 필수
    return Stack(
      children: [
        MapWidget(
          styleUri: "mapbox://styles/hanajungjun/cmjztbzby003i01sth91eayzw",
          cameraOptions: CameraOptions(
            center: Point(coordinates: Position(10, 20)),
            zoom: 1.3,
          ),
          gestureRecognizers: widget.isReadOnly
              ? <Factory<OneSequenceGestureRecognizer>>{
                  Factory<EagerGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                }
              : <Factory<OneSequenceGestureRecognizer>>{
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
              await map.setBounds(
                CameraBoundsOptions(minZoom: 0.8, maxZoom: 6.0),
              );
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

    try {
      await _map!.style.setProjection(
        StyleProjection(name: StyleProjectionName.mercator),
      );
    } catch (_) {}

    await _localizeLabels();
    await _loadUserMapAccess();
    await _drawAll();

    // 메인 화면일 때만 마지막 여행지로 스으윽 이동
    if (widget.showLastTravelFocus) {
      await _focusOnLastTravel();
    }

    _safeSetState(() => _ready = true);
  }

  Future<void> _focusOnLastTravel() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _map == null) return;

    final lastTravel = await Supabase.instance.client
        .from('travels')
        .select('region_lat, region_lng, country_lat, country_lng')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (lastTravel != null) {
      double? lat =
          (lastTravel['region_lat'] ?? lastTravel['country_lat']) as double?;
      double? lng =
          (lastTravel['region_lng'] ?? lastTravel['country_lng']) as double?;

      if (lat != null && lng != null) {
        await _map!.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(lng, lat)),
            zoom: 3.5,
          ),
          MapAnimationOptions(duration: 2500),
        );
      }
    }
  }

  Future<void> _loadUserMapAccess() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final res = await Supabase.instance.client
        .from('users')
        .select('active_maps')
        .eq('auth_uid', user.id)
        .maybeSingle();
    final List activeMaps = (res?['active_maps'] as List?) ?? [];
    _hasUsaAccess = activeMaps.contains('us');
  }

  Future<void> _drawAll() async {
    final map = _map;
    if (map == null) return;
    final style = map.style;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final travels = await Supabase.instance.client
        .from('travels')
        .select('country_code, region_name, is_completed, travel_type')
        .eq('user_id', user.id);
    final Set<String> visitedCountries = {};
    final Set<String> completedCountries = {};
    final Set<String> visitedStates = {};
    final Set<String> completedStates = {};

    for (final t in (travels as List)) {
      final code = t['country_code']?.toString().toUpperCase();
      if (code == null || code.isEmpty) continue;
      visitedCountries.add(code);
      if (t['is_completed'] == true) {
        if (!_hasUsaAccess || code != 'US') completedCountries.add(code);
      }
      if (code == 'US' && t['travel_type']?.toString() == 'usa') {
        final rn = t['region_name']?.toString();
        if (rn != null) {
          visitedStates.add(rn);
          if (t['is_completed'] == true) completedStates.add(rn);
        }
      }
    }

    final worldJson = await rootBundle.loadString(_worldGeo);
    await _rm(style, _worldFill, _worldSource);
    await style.addSource(GeoJsonSource(id: _worldSource, data: worldJson));
    await style.addLayer(FillLayer(id: _worldFill, sourceId: _worldSource));

    try {
      if (await style.styleLayerExists('country-label')) {
        await style.moveStyleLayer(
          _worldFill,
          LayerPosition(below: 'country-label'),
        );
      }
    } catch (_) {}

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

    final doneHex = _hex(AppColors.mapOverseaVisitedFill);
    final activeHex = _hex(
      const Color.fromARGB(255, 144, 73, 77).withOpacity(0.25),
    );
    final usaBaseHex = _hex(
      const Color.fromARGB(255, 216, 219, 221).withOpacity(0.12),
    );

    final worldColorExpr = [
      'case',
      [
        'all',
        [
          'any',
          [
            '==',
            ['get', 'ISO_A2'],
            'US',
          ],
          [
            '==',
            ['get', 'iso_a2'],
            'US',
          ],
          [
            '==',
            ['get', 'ISO_A2_EH'],
            'US',
          ],
        ],
        _hasUsaAccess,
      ],
      usaBaseHex,
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
    ];
    await style.setStyleLayerProperty(_worldFill, 'fill-color', worldColorExpr);
    await style.setStyleLayerProperty(_worldFill, 'fill-opacity', 0.7);

    if (_hasUsaAccess) {
      try {
        final usaJson = await rootBundle.loadString(_usaGeo);
        await _rm(style, _usaFill, _usaSource);
        await style.addSource(GeoJsonSource(id: _usaSource, data: usaJson));
        await style.addLayer(FillLayer(id: _usaFill, sourceId: _usaSource));
        try {
          if (await style.styleLayerExists('state-label')) {
            await style.moveStyleLayer(
              _usaFill,
              LayerPosition(below: 'state-label'),
            );
          }
        } catch (_) {}
        await style.setStyleLayerProperty(_usaFill, 'filter', [
          'in',
          [
            'upcase',
            ['get', 'NAME'],
          ],
          ['literal', visitedStates.toList()],
        ]);
        await style.setStyleLayerProperty(_usaFill, 'fill-color', [
          'case',
          [
            'in',
            [
              'upcase',
              ['get', 'NAME'],
            ],
            ['literal', completedStates.toList()],
          ],
          doneHex,
          _hex(const Color.fromARGB(255, 228, 176, 180).withOpacity(0.4)),
        ]);
        await style.setStyleLayerProperty(_usaFill, 'fill-opacity', 0.45);
      } catch (e) {
        debugPrint('❌ Error loading states: $e');
      }
    }
  }

  Future<void> _onMapTap(MapContentGestureContext ctx) async {
    final map = _map;
    if (map == null) return;
    final screen = await map.pixelForCoordinate(ctx.point);
    if (_hasUsaAccess) {
      final usa = await map.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screen),
        RenderedQueryOptions(layerIds: [_usaFill]),
      );
      if (usa.isNotEmpty) {
        final props = usa.first?.queriedFeature.feature['properties'] as Map?;
        final stateName = (props?['NAME'] ?? props?['name'])?.toString();
        if (stateName != null) {
          _showPopup(countryCode: 'US', regionName: stateName.toUpperCase());
          return;
        }
      }
    }
    final world = await map.queryRenderedFeatures(
      RenderedQueryGeometry.fromScreenCoordinate(screen),
      RenderedQueryOptions(layerIds: [_worldFill]),
    );
    if (world.isEmpty) return;
    final props = world.first?.queriedFeature.feature['properties'] as Map?;
    final code = (props?['ISO_A2_EH'] ?? props?['iso_a2'] ?? props?['ISO_A2'])
        ?.toString()
        .toUpperCase();
    if (code == null) return;
    final isKo = context.locale.languageCode == 'ko';
    final name = isKo
        ? (props?['NAME_KO'] ??
                  props?['name_ko'] ??
                  props?['NAME'] ??
                  props?['name'])
              ?.toString()
        : (props?['NAME'] ??
                  props?['name'] ??
                  props?['NAME_KO'] ??
                  props?['name_ko'])
              ?.toString();
    if (name != null) _showPopup(countryCode: code, regionName: name);
  }

  void _showPopup({
    required String countryCode,
    required String regionName,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    var query = Supabase.instance.client
        .from('travels')
        .select('map_image_url, ai_cover_summary, is_completed')
        .eq('user_id', user.id)
        .eq('country_code', countryCode);
    if (countryCode == 'US') {
      query = query.eq('travel_type', 'usa').eq('region_name', regionName);
    } else {
      query = query.eq('travel_type', 'overseas');
    }
    final res = await query
        .eq('is_completed', true)
        .order('completed_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Global AI Map',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (_, anim, __, ___) => Opacity(
        opacity: anim.value,
        child: AiMapPopup(
          imageUrl: res['map_image_url']?.toString() ?? '',
          regionName: regionName,
          summary: res['ai_cover_summary']?.toString() ?? '',
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

  Future<void> _rm(StyleManager s, String layer, String source) async {
    if (await s.styleLayerExists(layer)) await s.removeStyleLayer(layer);
    if (await s.styleSourceExists(source)) await s.removeStyleSource(source);
  }
}
