// global_map_page.dart
// 글로벌 여행 지도 위젯.
// 렌더링 로직은 MapLayerManager, 데이터는 MapDataService, 상수는 MapConstants로 분리.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/core/widgets/ai_map_popup.dart';
import 'package:travel_memoir/storage_urls.dart';

import 'package:travel_memoir/features/map/widgets/detailed_map_config.dart';
import 'package:travel_memoir/features/map/widgets/map_constants.dart';
import 'package:travel_memoir/features/map/widgets/map_data_service.dart';
import 'package:travel_memoir/features/map/widgets/map_layer_manager.dart';
import 'package:travel_memoir/features/map/widgets/travel_map_data.dart';

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
  // ── 내부 상태 ────────────────────────────────────────────────────────────
  MapboxMap? _map;
  MapLayerManager? _layerManager;
  bool _initDone = false;
  bool _ready = false;

  /// 캐시된 월드 GeoJSON (_drawAll 재호출 시 재로드 방지)
  String? _cachedWorldJson;

  /// 구매된 맵 ID (소문자)
  Set<String> _purchasedMapIds = {};

  /// 서비스 레이어
  late final MapDataService _dataService;

  @override
  bool get wantKeepAlive => true;

  // ── 색상 헬퍼 ────────────────────────────────────────────────────────────
  String _hex(Color c) =>
      '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  bool _hasAccess(String countryCode) =>
      _purchasedMapIds.contains(countryCode.toLowerCase());

  // ── 구매된 서브맵 중 US를 제외한 국가 코드 목록 ──────────────────────────
  List<String> get _purchasedSubMapCodesExceptUs => kSupportedDetailedMaps
      .where(
        (c) =>
            c.countryCode != MapConstants.usCode && _hasAccess(c.countryCode),
      )
      .map((c) => c.countryCode)
      .toList();

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _dataService = MapDataService();
  }

  @override
  void didUpdateWidget(GlobalMapPage old) {
    super.didUpdateWidget(old);
    if (old.isReadOnly != widget.isReadOnly) {
      _applyGestureSettings();
    }
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  // ── Public API ───────────────────────────────────────────────────────────

  Future<void> refreshData() async {
    if (_map == null) return;
    await _drawAll();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        MapWidget(
          styleUri: "mapbox://styles/hanajungjun/cmjztbzby003i01sth91eayzw",
          gestureRecognizers: widget.isReadOnly
              ? <Factory<OneSequenceGestureRecognizer>>{
                  Factory<ScaleGestureRecognizer>(
                    () => ScaleGestureRecognizer(),
                  ),
                  Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
                }
              : <Factory<OneSequenceGestureRecognizer>>{
                  // ✅ EagerGestureRecognizer 대신 이걸로 교체
                  Factory<ScaleGestureRecognizer>(
                    () => ScaleGestureRecognizer(),
                  ),
                  Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
                },
          cameraOptions: CameraOptions(
            center: Point(
              coordinates: Position(
                MapConstants.defaultLng,
                MapConstants.defaultLat,
              ),
            ),
            zoom: MapConstants.defaultZoom,
          ),
          onMapCreated: _onMapCreated,
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

  // ── 맵 초기화 ────────────────────────────────────────────────────────────

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    try {
      await map.setBounds(
        CameraBoundsOptions(
          minZoom: MapConstants.minZoom,
          maxZoom: MapConstants.maxZoom,
        ),
      );
    } catch (e) {
      _log('setBounds 실패: $e');
    }
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    if (_initDone || _map == null) return;
    _initDone = true;

    _layerManager = MapLayerManager(_map!.style);

    await WidgetsBinding.instance.endOfFrame;
    await Future.delayed(
      const Duration(milliseconds: MapConstants.initDelayMs),
    );
    if (!mounted || _map == null) return;

    await Future.wait([_applyGestureSettings(), _setMercatorProjection()]);

    await _layerManager!.localizeLabels(context.locale.languageCode);

    // 권한 로드 → 렌더링 순서 보장
    _purchasedMapIds = await _dataService.fetchPurchasedMapIds();
    _safeSetState(() {});

    await _drawAll();

    if (widget.showLastTravelFocus) {
      await _focusOnLastTravel();
    }

    _safeSetState(() => _ready = true);
  }

  Future<void> _setMercatorProjection() async {
    try {
      await _map!.style.setProjection(
        StyleProjection(name: StyleProjectionName.mercator),
      );
    } catch (e) {
      _log('setProjection 실패: $e');
    }
  }

  Future<void> _applyGestureSettings() async {
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
                simultaneousRotateAndPinchToZoomEnabled: true,
              ),
      );
    } catch (e) {
      _log('_applyGestureSettings 실패: $e');
    }
  }

  // ── 렌더링 ───────────────────────────────────────────────────────────────

  Future<void> _drawAll() async {
    final manager = _layerManager;
    if (manager == null || !mounted) return;

    try {
      // 1) 현지화(재호출 포함)
      await manager.localizeLabels(context.locale.languageCode);

      // 2) 여행 데이터 로드
      final data = await _dataService.fetchTravelMapData();

      // 3) 캐시된 월드 GeoJSON 로드
      _cachedWorldJson ??= await rootBundle.loadString(
        MapConstants.worldGeoJson,
      );

      // 4) 월드맵 레이어 세팅
      await manager.setupWorldLayer(_cachedWorldJson!);
      await manager.applyWorldExpressions(
        data: data,
        hasUsAccess: _hasAccess(MapConstants.usCode),
        purchasedSubMapCodes: _purchasedSubMapCodesExceptUs,
        doneHex: _hex(AppColors.mapFill),
        activeHex: _hex(AppColors.mapActiveFill),
        subMapBaseHex: _hex(AppColors.mapSubMapBase),
        usHex: _hex(AppColors.travelingRed),
      );

      // 5) 서브맵(상세 지도) 렌더링
      for (final config in kSupportedDetailedMaps) {
        if (!_hasAccess(config.countryCode)) continue;

        await Future.delayed(
          const Duration(milliseconds: MapConstants.subMapDelayMs),
        );
        await _drawSubMap(manager, config, data);
      }
    } catch (e) {
      _log('_drawAll 오류: $e');
    }
  }

  Future<void> _drawSubMap(
    MapLayerManager manager,
    DetailedMapConfig config,
    TravelMapData data,
  ) async {
    final isUs = config.countryCode == MapConstants.usCode;
    final doneHex = isUs
        ? _hex(AppColors.travelingRed)
        : _hex(AppColors.mapFill);
    final activeHex = isUs
        ? _hex(AppColors.travelingRed)
        : _hex(AppColors.mapActiveFill);

    try {
      await manager.setupSubMapLayer(config);
      await manager.applySubMapExpressions(
        config: config,
        visitedRegions: data.visitedRegions[config.countryCode] ?? {},
        completedRegions: data.completedRegions[config.countryCode] ?? {},
        doneHex: doneHex,
        activeHex: activeHex,
      );
    } catch (e) {
      _log('_drawSubMap(${config.countryCode}) 오류: $e');
    }
  }

  // ── 탭 처리 ──────────────────────────────────────────────────────────────

  Future<void> _onMapTap(MapContentGestureContext ctx) async {
    if (_map == null) return;

    final screen = await _map!.pixelForCoordinate(ctx.point);

    // 1) 상세 지도 레이어 우선 확인
    for (final config in kSupportedDetailedMaps) {
      if (!_hasAccess(config.countryCode)) continue;

      final features = await _map!.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screen),
        RenderedQueryOptions(layerIds: [config.layerId]),
      );
      if (features.isEmpty) continue;

      final props =
          features.first?.queriedFeature.feature['properties'] as Map?;
      final regionName = (props?['NAME'] ?? props?['name'])?.toString();
      if (regionName != null) {
        await _showPopup(
          countryCode: config.countryCode,
          regionName: regionName.toUpperCase(),
          isDetailed: true,
        );
        return;
      }
    }

    // 2) 월드맵 레이어 확인
    final world = await _map!.queryRenderedFeatures(
      RenderedQueryGeometry.fromScreenCoordinate(screen),
      RenderedQueryOptions(layerIds: [MapConstants.worldFillLayer]),
    );
    if (world.isEmpty) return;

    final props = world.first?.queriedFeature.feature['properties'] as Map?;
    String? code = (props?['ISO_A2'] ?? props?['iso_a2'] ?? props?['ISO_A2_EH'])
        ?.toString()
        .toUpperCase();

    final String? rawName =
        props?['name']?.toString() ?? props?['NAME']?.toString();

    // 코소보 예외 처리
    if (rawName != null && rawName.contains('Kosovo')) {
      code = MapConstants.kosovoCode;
    }
    if (code == null) return;

    final isKo = context.locale.languageCode == 'ko';
    String name =
        (isKo
                ? (props?['NAME_KO'] ?? props?['NAME'] ?? '코소보')
                : (props?['NAME'] ?? props?['NAME_KO'] ?? 'Kosovo'))
            .toString();
    if (code == MapConstants.kosovoCode) name = 'kosovo'.tr();

    await _showPopup(countryCode: code, regionName: name, isDetailed: false);
  }

  // ── 팝업 ─────────────────────────────────────────────────────────────────

  Future<void> _showPopup({
    required String countryCode,
    required String regionName,
    required bool isDetailed,
  }) async {
    final result = await _dataService.fetchPopupData(
      countryCode: countryCode,
      regionName: isDetailed ? regionName : null,
    );
    if (result == null || !mounted) return;

    final finalUrl =
        (countryCode == MapConstants.usCode && _hasAccess(MapConstants.usCode))
        ? StorageUrls.usaMapFromPath(result.imageUrl)
        : StorageUrls.globalMapFromPath('${countryCode.toUpperCase()}.webp');

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
          summary: result.summary.isEmpty
              ? 'no_memories_recorded'.tr()
              : result.summary,
        ),
      ),
    );
  }

  // ── 카메라 포커스 ─────────────────────────────────────────────────────────

  Future<void> _focusOnLastTravel() async {
    if (_map == null) return;

    final coords = await _dataService.fetchLastTravelCoordinates();
    if (coords == null || !mounted || _map == null) return;

    final zoom = coords.lat < MapConstants.antarcticaMaxLat
        ? MapConstants.antarcticaZoom
        : MapConstants.focusZoom;

    final cameraOptions = CameraOptions(
      center: Point(coordinates: Position(coords.lng, coords.lat)),
      zoom: zoom,
    );

    if (widget.animateFocus) {
      await _map!.flyTo(
        cameraOptions,
        MapAnimationOptions(duration: MapConstants.flyToDurationMs),
      );
    } else {
      await _map!.setCamera(cameraOptions);
    }
  }

  // ── 유틸 ─────────────────────────────────────────────────────────────────

  void _log(String msg) {
    assert(() {
      // ignore: avoid_print
      print('⚠️ [GlobalMapPage] $msg');
      return true;
    }());
  }
}
