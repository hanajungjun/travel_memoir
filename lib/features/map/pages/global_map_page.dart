// global_map_page.dart
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/core/widgets/ai_map_popup.dart';
import 'package:travel_memoir/storage_urls.dart';
import 'package:travel_memoir/env.dart';
import 'package:travel_memoir/features/map/widgets/map_constants.dart';
import 'package:travel_memoir/features/map/widgets/map_data_service.dart';

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
  final MapController _mapController = MapController();
  late final MapDataService _dataService;

  // 나라 단위 폴리곤
  List<Polygon> _polygons = [];
  Map<String, List<List<LatLng>>> _countryPolygonsData = {};

  // ✅ 언어별 나라 이름 분리 저장 (탭 시점에 locale 읽기 위해)
  Map<String, String> _countryNameKo = {};
  Map<String, String> _countryNameEn = {};

  // 캐시된 월드 GeoJSON
  String? _cachedWorldJson;

  // 구매된 맵 ID
  Set<String> _purchasedMapIds = {};

  // 미국 주 단위 폴리곤
  List<Polygon> _usStatePolygons = [];
  Map<String, List<List<LatLng>>> _usStatePolygonsData = {};

  bool _ready = false;

  @override
  bool get wantKeepAlive => true;

  bool _hasAccess(String countryCode) =>
      _purchasedMapIds.contains(countryCode.toLowerCase());

  @override
  void initState() {
    super.initState();
    _dataService = MapDataService();
    _initMapData();
  }

  Future<void> _initMapData() async {
    try {
      _purchasedMapIds = await _dataService.fetchPurchasedMapIds();
      final travelData = await _dataService.fetchTravelMapData();

      // 캐싱: 최초 1회만 로드
      _cachedWorldJson ??= await rootBundle.loadString(
        MapConstants.worldGeoJson,
      );
      final data = json.decode(_cachedWorldJson!);

      final List<Polygon> newPolygons = [];
      final Map<String, List<List<LatLng>>> newData = {};

      // ✅ ko/en 분리
      final Map<String, String> newNameKo = {};
      final Map<String, String> newNameEn = {};

      final doneColor = AppColors.mapFill.withOpacity(0.8);
      final activeColor = AppColors.mapActiveFill.withOpacity(0.8);

      for (var feature in data['features']) {
        final props = feature['properties'];
        String code =
            (props['ISO_A2'] ?? props['iso_a2'] ?? props['ISO_A2_EH'])
                ?.toString()
                .toUpperCase() ??
            '';

        final rawName = props['name']?.toString() ?? props['NAME']?.toString();
        if (rawName != null && rawName.contains('Kosovo')) {
          code = MapConstants.kosovoCode;
        }
        if (code.isEmpty) continue;

        // ✅ 저장 시점에 locale 판단 없이 ko/en 둘 다 저장
        if (code == MapConstants.kosovoCode) {
          newNameKo[code] = 'kosovo'.tr();
          newNameEn[code] = 'Kosovo';
        } else {
          newNameKo[code] =
              (props['NAME_KO'] ?? props['name'] ?? props['NAME'] ?? code)
                  .toString();
          newNameEn[code] = (props['name'] ?? props['NAME'] ?? code).toString();
        }

        Color fillColor = Colors.transparent;

        if (code == MapConstants.usCode && _hasAccess(MapConstants.usCode)) {
          fillColor = AppColors.travelingRed.withOpacity(0.4);
        } else if (travelData.visitedCountries.contains(code)) {
          fillColor = travelData.completedCountries.contains(code)
              ? doneColor
              : activeColor;
        }

        if (fillColor != Colors.transparent) {
          final geometry = feature['geometry'];
          List<List<LatLng>> multiPoints = [];
          if (geometry['type'] == 'Polygon') {
            var pts = _extract(geometry['coordinates']);
            multiPoints.add(pts);
            newPolygons.add(
              Polygon(
                points: pts,
                color: fillColor,
                borderStrokeWidth: 0.5,
                borderColor: Colors.white,
              ),
            );
          } else if (geometry['type'] == 'MultiPolygon') {
            for (var poly in geometry['coordinates']) {
              var pts = _extract(poly);
              multiPoints.add(pts);
              newPolygons.add(
                Polygon(
                  points: pts,
                  color: fillColor,
                  borderStrokeWidth: 0.5,
                  borderColor: Colors.white,
                ),
              );
            }
          }
          newData[code] = multiPoints;
        }
      }

      // 미국 주별 색칠 (구매했을 때만)
      if (_hasAccess(MapConstants.usCode)) {
        await _loadUsStates();
      }

      if (mounted) {
        setState(() {
          _polygons = newPolygons;
          _countryPolygonsData = newData;
          _countryNameKo = newNameKo; // ✅
          _countryNameEn = newNameEn; // ✅
          _ready = true;
        });
        if (widget.showLastTravelFocus) _focusOnLast();
      }
    } catch (e) {
      debugPrint('⚠️ GlobalMap Error: $e');
    }
  }

  Future<void> _loadUsStates() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final travels = await Supabase.instance.client
        .from('travels')
        .select('region_name, is_completed')
        .eq('user_id', user.id)
        .eq('travel_type', 'usa');

    final Set<String> visitedStates = {};
    final Set<String> completedStates = {};

    for (final t in (travels as List)) {
      final name = t['region_name']?.toString().toUpperCase();
      if (name != null) {
        visitedStates.add(name);
        if (t['is_completed'] == true) completedStates.add(name);
      }
    }

    final usaJson = await rootBundle.loadString(
      'assets/geo/processed/usa_states_standard.json',
    );
    final data = json.decode(usaJson);
    final List<Polygon> statePolygons = [];
    final Map<String, List<List<LatLng>>> stateData = {};

    for (var feature in data['features']) {
      final props = feature['properties'];
      final name = (props['NAME'] ?? '').toString().toUpperCase();
      if (!visitedStates.contains(name)) continue;

      final fillColor = completedStates.contains(name)
          ? AppColors.travelingRed.withOpacity(0.8)
          : AppColors.travelingRed.withOpacity(0.5);

      final geometry = feature['geometry'];
      if (!stateData.containsKey(name)) stateData[name] = [];

      if (geometry['type'] == 'Polygon') {
        final pts = _extract(geometry['coordinates']);
        statePolygons.add(
          Polygon(
            points: pts,
            color: fillColor,
            borderStrokeWidth: 0.5,
            borderColor: Colors.white,
          ),
        );
        stateData[name]!.add(pts);
      } else if (geometry['type'] == 'MultiPolygon') {
        for (var poly in geometry['coordinates']) {
          final pts = _extract(poly);
          statePolygons.add(
            Polygon(
              points: pts,
              color: fillColor,
              borderStrokeWidth: 0.5,
              borderColor: Colors.white,
            ),
          );
          stateData[name]!.add(pts);
        }
      }
    }

    if (mounted) {
      setState(() {
        _usStatePolygons = statePolygons;
        _usStatePolygonsData = stateData;
      });
    }
  }

  List<LatLng> _extract(List coords) {
    final List list = coords[0] is List ? coords[0] : coords;
    return list.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
  }

  void _handleTap(LatLng point) {
    if (widget.isReadOnly) return;

    // 미국 주 먼저 확인
    if (_usStatePolygonsData.isNotEmpty) {
      for (var entry in _usStatePolygonsData.entries) {
        for (var poly in entry.value) {
          if (_isPointInPoly(point, poly)) {
            _showUsStatePopup(stateName: entry.key);
            return;
          }
        }
      }
    }

    // 나라 단위 확인
    String? hitCode;
    for (var entry in _countryPolygonsData.entries) {
      for (var poly in entry.value) {
        if (_isPointInPoly(point, poly)) {
          hitCode = entry.key;
          break;
        }
      }
      if (hitCode != null) break;
    }

    // 미국은 나라 단위 팝업 제외 (주 단위로만)
    if (hitCode != null && hitCode != MapConstants.usCode) {
      // ✅ 탭 시점에 locale 판단 → 항상 정확한 언어로 표시
      final isKo = context.locale.languageCode == 'ko';
      final regionName = isKo
          ? (_countryNameKo[hitCode] ?? hitCode)
          : (_countryNameEn[hitCode] ?? hitCode);

      _showPopup(
        countryCode: hitCode,
        regionName: regionName,
        isDetailed: false,
      );
    }
  }

  bool _isPointInPoly(LatLng p, List<LatLng> poly) {
    var isInside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      if (((poly[i].longitude > p.longitude) !=
              (poly[j].longitude > p.longitude)) &&
          (p.latitude <
              (poly[j].latitude - poly[i].latitude) *
                      (p.longitude - poly[i].longitude) /
                      (poly[j].longitude - poly[i].longitude) +
                  poly[i].latitude)) {
        isInside = !isInside;
      }
    }
    return isInside;
  }

  String get _mapStyleId {
    switch (context.locale.languageCode) {
      case 'ko':
        return 'hanajungjun/cmmu9b4h400bc01sk8irsdheu'; // 한국어
      default:
        return 'hanajungjun/cmjztbzby003i01sth91eayzw'; // 영어(기본)
    }
  }

  Future<void> _focusOnLast() async {
    final coords = await _dataService.fetchLastTravelCoordinates();
    if (!mounted) return;
    if (coords != null) {
      try {
        _mapController.move(
          LatLng(coords.lat, coords.lng),
          MapConstants.focusZoom,
        );
      } catch (e) {
        debugPrint('Map move ignored: $e');
      }
    }
  }

  Future<void> refreshData() async {
    if (!mounted) return;
    await _initMapData();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        Positioned.fill(
          child: Focus(
            canRequestFocus: false,
            descendantsAreFocusable: false,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(25.0, 10.0),
                initialZoom: 2.5,
                minZoom: 2.5,
                maxZoom: 10.0,
                backgroundColor: const Color(0xFFC0D5DF),
                onTap: (_, point) => _handleTap(point),
                cameraConstraint: CameraConstraint.unconstrained(),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://api.mapbox.com/styles/v1/{styleId}/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}',
                  additionalOptions: {
                    'styleId': _mapStyleId, // ← 여기만 변경
                    'accessToken': AppEnv.mapboxAccessToken,
                  },
                  userAgentPackageName: 'com.hanajungjun.travelmemoir',
                  panBuffer: 1,
                ),
                PolygonLayer(polygons: [..._polygons, ..._usStatePolygons]),
              ],
            ),
          ),
        ),
        if (!_ready)
          Container(
            color: Colors.white,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Future<void> _showPopup({
    required String countryCode,
    required String regionName,
    required bool isDetailed,
  }) async {
    final result = await _dataService.fetchPopupData(countryCode: countryCode);
    if (result == null || !mounted) return;

    final finalUrl = StorageUrls.globalMapFromPath(
      '${countryCode.toUpperCase()}.webp',
    );

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
          summary: result.summary.isEmpty
              ? 'no_memories_recorded'.tr()
              : result.summary,
        ),
      ),
    );
  }

  Future<void> _showUsStatePopup({required String stateName}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final results = await Supabase.instance.client
        .from('travels')
        .select()
        .eq('user_id', user.id)
        .eq('travel_type', 'usa')
        .ilike('region_name', stateName)
        .eq('is_completed', true)
        .order('created_at', ascending: false)
        .limit(1);

    if (results.isEmpty || !mounted) return;

    final res = results.first;
    final rawSummary = (res['ai_cover_summary'] ?? '').toString();
    final cleanedSummary = rawSummary.replaceAll('**', '').trim();
    final rawPath = res['map_image_url']?.toString();
    final imageUrl = rawPath != null && rawPath.isNotEmpty
        ? StorageUrls.usaMapFromPath(rawPath)
        : '';

    final langCode = context.locale.languageCode;
    final displayName = langCode == 'en'
        ? stateName
        : (res['region_name']?.toString() ?? stateName);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Popup',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (_, anim, __, ___) => Opacity(
        opacity: anim.value,
        child: AiMapPopup(
          imageUrl: imageUrl,
          regionName: displayName,
          summary: cleanedSummary.isEmpty
              ? 'no_memories_recorded'.tr()
              : cleanedSummary,
        ),
      ),
    );
  }
}
