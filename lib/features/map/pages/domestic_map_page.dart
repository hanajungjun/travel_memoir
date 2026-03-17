import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart'; // ✅ flutter_map 사용
import 'package:latlong2/latlong.dart'; // ✅ 좌표용
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/storage_urls.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/core/widgets/ai_map_popup.dart';
import 'package:travel_memoir/core/utils/travel_utils.dart';
import 'package:travel_memoir/core/constants/korea/sgg_code_map.dart';
import 'package:travel_memoir/env.dart'; // ✅ 토큰 가져오기용
import 'dart:convert';

class DomesticMapPage extends StatefulWidget {
  final bool readOnly;
  const DomesticMapPage({super.key, this.readOnly = false});

  @override
  State<DomesticMapPage> createState() => DomesticMapPageState();
}

class DomesticMapPageState extends State<DomesticMapPage>
    with AutomaticKeepAliveClientMixin {
  final MapController _mapController = MapController();
  List<Polygon> _polygons = [];
  Map<String, List<List<LatLng>>> _sggPolygonsData = {}; // 터치 계산용

  @override
  bool get wantKeepAlive => true;

  static const _sigGeoJson = 'assets/geo/processed/korea_sig.geojson';

  @override
  void initState() {
    super.initState();
    _loadAndDrawMap();
  }

  Future<void> refreshData() async {
    await _loadAndDrawMap();
  }

  // ✅ GeoJSON 로드 및 색칠 로직
  Future<void> _loadAndDrawMap() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final travels = await Supabase.instance.client
          .from('travels')
          .select('region_id, is_completed')
          .eq('user_id', user.id)
          .eq('travel_type', 'domestic');

      final Set<String> allSgg = {};
      final Set<String> completedSgg = {};

      for (final t in travels) {
        final regId = t['region_id']?.toString() ?? '';
        final codeInfo = SggCodeMap.fromRegionId(regId);
        if (codeInfo.sggCd != null) {
          final sgg = codeInfo.sggCd!;
          allSgg.add(sgg);
          if (t['is_completed'] == true) completedSgg.add(sgg);
          if (TravelUtils.majorCityMapping.containsKey(sgg)) {
            allSgg.addAll(TravelUtils.majorCityMapping[sgg]!);
            if (t['is_completed'] == true)
              completedSgg.addAll(TravelUtils.majorCityMapping[sgg]!);
          }
        }
      }

      final jsonString = await rootBundle.loadString(_sigGeoJson);
      final data = json.decode(jsonString);
      final List<Polygon> newPolygons = [];
      final Map<String, List<List<LatLng>>> newData = {};

      final doneColor = AppColors.travelingBlue.withOpacity(0.8);
      final activeColor = const Color.fromARGB(
        255,
        141,
        189,
        223,
      ).withOpacity(0.8);

      for (var feature in data['features']) {
        final sggCd = feature['properties']['SGG_CD'].toString();
        if (!allSgg.contains(sggCd)) continue;

        final color = completedSgg.contains(sggCd) ? doneColor : activeColor;
        final geometry = feature['geometry'];
        List<List<LatLng>> multiPoints = [];

        if (geometry['type'] == 'Polygon') {
          var pts = _extract(geometry['coordinates']);
          multiPoints.add(pts);
          newPolygons.add(
            Polygon(
              points: pts,
              color: color,
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
                color: color,
                borderStrokeWidth: 0.5,
                borderColor: Colors.white,
              ),
            );
          }
        }
        newData[sggCd] = multiPoints;
      }

      if (mounted) {
        setState(() {
          _polygons = newPolygons;
          _sggPolygonsData = newData;
        });
      }
    } catch (e) {
      debugPrint('❌ [MAP ERROR] $e');
    }
  }

  List<LatLng> _extract(List coords) {
    final List list = coords[0] is List ? coords[0] : coords;
    return list.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
  }

  String get _mapStyleId {
    switch (context.locale.languageCode) {
      case 'ko':
        return 'hanajungjun/cmmu9b4h400bc01sk8irsdheu'; // 한국어
      default:
        return 'hanajungjun/cmjztbzby003i01sth91eayzw'; // 영어(기본)
    }
  }

  // ✅ 터치 시 지역 판별 (Ray-casting)
  void _handleMapTap(LatLng tapPoint) {
    if (widget.readOnly) return;
    String? hitSggCode;

    for (var entry in _sggPolygonsData.entries) {
      for (var poly in entry.value) {
        if (_isPointInPolygon(tapPoint, poly)) {
          hitSggCode = entry.key;
          break;
        }
      }
      if (hitSggCode != null) break;
    }

    if (hitSggCode != null) {
      String lookup = hitSggCode!;
      TravelUtils.majorCityMapping.forEach((parent, children) {
        if (children.contains(hitSggCode)) lookup = parent;
      });
      final regId = SggCodeMap.getRegionIdFromSggCd(lookup);
      if (regId.isNotEmpty) _handlePopup(regId);
    }
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    var lat = point.latitude;
    var lng = point.longitude;
    var intersect = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      if (((polygon[i].longitude > lng) != (polygon[j].longitude > lng)) &&
          (lat <
              (polygon[j].latitude - polygon[i].latitude) *
                      (lng - polygon[i].longitude) /
                      (polygon[j].longitude - polygon[i].longitude) +
                  polygon[i].latitude)) {
        intersect = !intersect;
      }
    }
    return intersect;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(36.3, 127.8),
        initialZoom: 6.2,
        minZoom: 5.0,
        maxZoom: 12.0,
        onTap: (tapPosition, point) => _handleMapTap(point),
        // ✅ 한국 영역 밖으로 못 나가게
        cameraConstraint: CameraConstraint.containCenter(
          bounds: LatLngBounds(
            const LatLng(32.5, 124.0), // 남서쪽
            const LatLng(40.0, 131.2), // 북동쪽
          ),
        ),
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
          tileSize: 256,
          tileDisplay: const TileDisplay.fadeIn(
            duration: Duration(milliseconds: 300), // ✅ 수정완료
          ),
        ),
        // 시군구 색칠 레이어
        PolygonLayer(polygons: _polygons),
      ],
    );
  }

  void _handlePopup(String regId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final List<dynamic> results = await Supabase.instance.client
          .from('travels')
          .select()
          .eq('user_id', user.id)
          .eq('region_id', regId)
          .eq('is_completed', true)
          .order('created_at', ascending: false)
          .limit(1);

      if (results.isNotEmpty) {
        final res = results.first;
        final String langCode = context.locale.languageCode;
        final bool isEn = langCode == 'en';

        String displayRegionName = '';
        if (isEn) {
          final String regIdStr = res['region_id']?.toString() ?? '';
          displayRegionName = regIdStr.contains('_')
              ? regIdStr.split('_').last.toUpperCase()
              : res['region_name'].toString().toUpperCase();
        } else {
          displayRegionName = "${res['province']} ${res['region_name']}";
        }

        final String rawSummary = (res['ai_cover_summary'] ?? '').toString();
        final String cleanedSummary = rawSummary.replaceAll('**', '').trim();
        final rawPath = res['map_image_url']?.toString();

        String imageUrl = '';
        if (rawPath != null && rawPath.isNotEmpty) {
          imageUrl = StorageUrls.domesticMapFromPath(rawPath);
        }

        if (!mounted) return;

        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: "AI Map",
          barrierColor: Colors.black54,
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (context, anim1, anim2) => Center(
            child: AiMapPopup(
              imageUrl: imageUrl,
              regionName: displayRegionName,
              summary: cleanedSummary.isEmpty
                  ? 'no_memories_recorded'.tr()
                  : cleanedSummary,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [MAP POPUP ERROR] $e');
    }
  }
}
