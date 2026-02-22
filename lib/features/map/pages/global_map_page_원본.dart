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
  final bool animateFocus;

  const GlobalMapPage({
    super.key,
    this.isReadOnly = false,
    this.showLastTravelFocus = false,
    this.animateFocus = false,
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
      //debugPrint("🔍 [LOG] 업데이트 제스처 설정... isReadOnly: ${widget.isReadOnly}");
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
    } catch (e) {
      debugPrint("⚠️ [ERROR] _updateMapGestures 실패: $e");
    }
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
    //debugPrint("🔄 [LOG] 데이터 새로고침 시작...");
    await _drawAll();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        MapWidget(
          styleUri: "mapbox://styles/hanajungjun/cmjztbzby003i01sth91eayzw",
          gestureRecognizers: widget.isReadOnly
              ? <Factory<OneSequenceGestureRecognizer>>{
                  Factory<EagerGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                }
              : null,
          // gestureRecognizers 블록 전체 삭제!
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
            } catch (e) {
              debugPrint("⚠️ [ERROR] setBounds 실패: $e");
            }
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
    //debugPrint("🎨 [LOG] 스타일 로드 완료. 초기화 시작...");
    _init = true;
    await WidgetsBinding.instance.endOfFrame;
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted || _map == null) return;
    await _updateMapGestures();
    try {
      await _map!.style.setProjection(
        StyleProjection(name: StyleProjectionName.mercator),
      );
    } catch (e) {
      debugPrint("⚠️ [ERROR] setProjection 실패: $e");
    }
    await _localizeLabels();
    await _loadUserMapAccess();
    await _drawAll();

    if (widget.showLastTravelFocus) {
      //debugPrint("🎯 [LOG] 마지막 여행지로 포커스 이동 시도");
      await _focusOnLastTravel();
    }
    _safeSetState(() => _ready = true);
  }

  Future<void> _loadUserMapAccess() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      //debugPrint("🔑 [LOG] 유저 권한 정보(active_maps) 조회 중...");
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
      //debugPrint("✅ [LOG] 구매된 지도 목록: $_purchasedMapIds");
    } catch (e) {
      debugPrint("⚠️ [ERROR] _loadUserMapAccess 실패: $e");
    }
  }

  Future<void> _drawAll() async {
    final map = _map;
    if (map == null || !mounted) return;
    final style = map.style;
    if (style == null) return;

    //debugPrint("🖌️ [LOG] _drawAll: 월드맵 그리기 시작");

    final doneHex = _hex(AppColors.mapFill);
    final activeHex = _hex(AppColors.mapActiveFill);
    final subMapBaseHex = _hex(AppColors.mapSubMapBase);
    final usRedHex = _hex(AppColors.travelingRed);

    try {
      await _localizeLabels();

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

      //debugPrint("📍 [LOG] 방문 국가 수: ${visitedCountries.length}, 완료 국가 수: ${completedCountries.length}",);
      String? _cachedWorldJson;

      // _drawAll() 안에서
      _cachedWorldJson ??= await rootBundle.loadString(_worldGeo);
      final worldJson = _cachedWorldJson!;

      await _rm(style, _worldFill, _worldSource);

      //debugPrint("🌍 [LOG] 월드 Source 추가 중...");
      await style.addSource(GeoJsonSource(id: _worldSource, data: worldJson));

      //debugPrint("🌍 [LOG] 월드 Layer 추가 중...");
      await style.addLayer(FillLayer(id: _worldFill, sourceId: _worldSource));

      final layers = await style.getStyleLayers();
      String? topmostRoadId;
      String? hillshadeId;
      for (var l in layers) {
        if (l == null) continue;
        if (l.id.contains('road') || l.id.contains('admin'))
          topmostRoadId = l.id;
        if (l.id.contains('hillshade') || l.id.contains('terrain'))
          hillshadeId = l.id;
      }

      if (topmostRoadId != null)
        await style.moveStyleLayer(
          _worldFill,
          LayerPosition(above: topmostRoadId),
        );
      if (hillshadeId != null)
        await style.moveStyleLayer(
          hillshadeId,
          LayerPosition(above: _worldFill),
        );
      if (await style.styleLayerExists('country-label')) {
        await style.moveStyleLayer(
          'country-label',
          LayerPosition(above: hillshadeId ?? _worldFill),
        );
      }

      // 🎯 필터 설정 (여기가 위험 구간 1)
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
      //debugPrint("⚙️ [LOG] _worldFill 필터 설정: $worldFilterExpr");
      await style.setStyleLayerProperty(_worldFill, 'filter', worldFilterExpr);

      // 🎯 색상 설정 (여기가 위험 구간 2)
      final List<dynamic> worldColorExpr = ['case'];
      final bool hasUsAccess = _hasAccess('US');

      if (hasUsAccess) {
        worldColorExpr.add([
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
        ]);
        worldColorExpr.add(usRedHex);
      }

      for (var config in _supportedDetailedMaps) {
        if (config.countryCode == 'US' && hasUsAccess) continue;
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

      //debugPrint("🎨 [LOG] _worldFill 색상 설정: $worldColorExpr");
      await style.setStyleLayerProperty(
        _worldFill,
        'fill-color',
        worldColorExpr,
      );

      // 🎯 투명도 설정
      final dynamic worldOpacityExpr = hasUsAccess
          ? [
              'case',
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
              ],
              0.25, // 미국용 투명도
              0.7, // 기본 투명도
            ]
          : 0.7; // 미국 권한 없으면 case 없이 숫자만 전달

      //debugPrint("🎨 [LOG] _worldFill 투명도 설정 (수정): $worldOpacityExpr");
      await style.setStyleLayerProperty(
        _worldFill,
        'fill-opacity',
        worldOpacityExpr,
      );

      // 서브맵(상세 지도) 그리기
      for (var config in _supportedDetailedMaps) {
        if (_hasAccess(config.countryCode)) {
          //debugPrint("🗺️ [LOG] 상세 지도 로드 시도: ${config.countryCode}");
          await Future.delayed(const Duration(milliseconds: 50));
          await _drawSubMap(
            style,
            config,
            visitedRegions[config.countryCode] ?? {},
            completedRegions[config.countryCode] ?? {},
            config.countryCode == 'US' ? usRedHex : doneHex,
            config.countryCode == 'US' ? usRedHex : activeHex,
          );
        }
      }
    } catch (e) {
      debugPrint("❌ [FATAL ERROR] _drawAll 에러 발생: $e");
    }
  }

  Future<void> _drawSubMap(
    StyleManager style,
    DetailedMapConfig config,
    Set<String> visited,
    Set<String> completed,
    String doneHex,
    String activeHex,
  ) async {
    try {
      //debugPrint("🖌️ [LOG] _drawSubMap 시작: ${config.countryCode}");
      final json = await rootBundle.loadString(config.geoJsonPath);
      await _rm(style, config.layerId, config.sourceId);

      await style.addSource(GeoJsonSource(id: config.sourceId, data: json));
      await style.addLayer(
        FillLayer(id: config.layerId, sourceId: config.sourceId),
      );

      // 필터 설정 (위험 구간 3)
      final subFilter = [
        'in',
        [
          'upcase',
          ['get', 'NAME'],
        ],
        ['literal', visited.toList()],
      ];
      //debugPrint("⚙️ [LOG] ${config.layerId} 필터 설정: $subFilter");
      await style.setStyleLayerProperty(config.layerId, 'filter', subFilter);

      // 색상 설정 (위험 구간 4)
      final subColor = [
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
        activeHex,
      ];
      //debugPrint("🎨 [LOG] ${config.layerId} 색상 설정: $subColor");
      await style.setStyleLayerProperty(config.layerId, 'fill-color', subColor);

      if (config.countryCode == 'US') {
        await style.setStyleLayerProperty(config.layerId, 'fill-opacity', [
          'case',
          [
            'in',
            [
              'upcase',
              ['get', 'NAME'],
            ],
            ['literal', completed.toList()],
          ],
          0.7,
          0.3,
        ]);
      } else {
        await style.setStyleLayerProperty(config.layerId, 'fill-opacity', 0.7);
      }
    } catch (e) {
      debugPrint('❌ [ERROR] _drawSubMap ${config.countryCode} 실패: $e');
    }
  }

  Future<void> _onMapTap(MapContentGestureContext ctx) async {
    if (_map == null) return;
    //debugPrint("🖱️ [LOG] Map Tap 감지: ${ctx.point.coordinates}");
    final screen = await _map!.pixelForCoordinate(ctx.point);

    // 상세 지도 레이어 확인
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
          //debugPrint("📍 [LOG] 서브맵 히트: $regionName (${config.countryCode})");
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

    // 월드맵 레이어 확인
    final world = await _map!.queryRenderedFeatures(
      RenderedQueryGeometry.fromScreenCoordinate(screen),
      RenderedQueryOptions(layerIds: [_worldFill]),
    );
    if (world.isEmpty) {
      //debugPrint("ℹ️ [LOG] 빈 영역 클릭");
      return;
    }

    final props = world.first?.queriedFeature.feature['properties'] as Map?;
    final String? rawName =
        props?['name']?.toString() ?? props?['NAME']?.toString();
    String? code = (props?['ISO_A2'] ?? props?['iso_a2'] ?? props?['ISO_A2_EH'])
        ?.toString()
        .toUpperCase();

    if (rawName != null && rawName.contains('Kosovo')) {
      code = 'XK';
    }

    //debugPrint("📍 [LOG] 월드맵 히트: $rawName (Code: $code)");
    if (code != null) {
      final isKo = context.locale.languageCode == 'ko';
      String name =
          (isKo
                  ? (props?['NAME_KO'] ?? props?['NAME'] ?? '코소보')
                  : (props?['NAME'] ?? props?['NAME_KO'] ?? 'Kosovo'))
              .toString();

      if (code == 'XK') name = 'kosovo'.tr();
      _showPopup(countryCode: code, regionName: name);
    }
  }

  void _showPopup({
    required String countryCode,
    required String regionName,
  }) async {
    //debugPrint("🖼️ [LOG] 팝업 호출: $countryCode / $regionName");
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    bool isDetailed = _hasAccess(countryCode);
    var query = Supabase.instance.client
        .from('travels')
        .select('map_image_url, ai_cover_summary')
        .eq('user_id', user.id)
        .eq('country_code', countryCode)
        .eq('is_completed', true);
    if (isDetailed) query = query.eq('region_name', regionName);

    final List<dynamic> results = await query
        .order('created_at', ascending: false)
        .limit(1);
    if (results.isEmpty) {
      //debugPrint("ℹ️ [LOG] 표시할 데이터 없음");
      return;
    }

    final res = results.first;
    final String rawSummary = (res['ai_cover_summary'] ?? '').toString();
    final String cleanedSummary = rawSummary.replaceAll('**', '').trim();
    final rawPath = res['map_image_url']?.toString() ?? '';

    String finalUrl = (countryCode == 'US' && _hasAccess('US'))
        ? StorageUrls.usaMapFromPath(rawPath)
        : StorageUrls.globalMapFromPath('${countryCode.toUpperCase()}.webp');

    if (!mounted) return;
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
          regionName: regionName.tr(),
          summary: cleanedSummary.isEmpty
              ? 'no_memories_recorded'.tr()
              : cleanedSummary,
        ),
      ),
    );
  }

  Future<void> _localizeLabels() async {
    final map = _map;
    if (map == null) return;
    final lang = context.locale.languageCode;
    final style = map.style;
    try {
      //debugPrint("🗣️ [LOG] 라벨 로컬라이징 중... ($lang)");
      final layers = await style.getStyleLayers();
      for (var l in layers) {
        if (l != null && (l.id.contains('label') || l.id.contains('place'))) {
          await style.setStyleLayerProperty(l.id, 'text-field', [
            'get',
            'name_$lang',
          ]);
          await style.setStyleLayerProperty(l.id, 'text-opacity', 0.4);
        }
      }
    } catch (e) {
      debugPrint("⚠️ [ERROR] _localizeLabels 실패: $e");
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
          .order('end_date', ascending: false)
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
          //debugPrint("📍 [LOG] 카메라 포커스 이동 타겟: $lat, $lng");
          double focusZoom = 3.5;
          if (lat < -60) focusZoom = 0.5;

          if (widget.animateFocus) {
            await _map!.flyTo(
              CameraOptions(
                center: Point(coordinates: Position(lng, lat)),
                zoom: focusZoom,
              ),
              MapAnimationOptions(duration: 2500),
            );
          } else {
            await _map!.setCamera(
              CameraOptions(
                center: Point(coordinates: Position(lng, lat)),
                zoom: focusZoom,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("⚠️ [ERROR] _focusOnLastTravel 실패: $e");
    }
  }

  Future<void> _rm(StyleManager s, String layer, String source) async {
    try {
      if (await s.styleLayerExists(layer)) {
        //debugPrint("🗑️ [LOG] 기존 레이어 삭제: $layer");
        await s.removeStyleLayer(layer);
      }
    } catch (_) {}
    try {
      if (await s.styleSourceExists(source)) {
        //debugPrint("🗑️ [LOG] 기존 소스 삭제: $source");
        await s.removeStyleSource(source);
      }
    } catch (_) {}
  }
}
