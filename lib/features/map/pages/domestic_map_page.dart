import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/storage_urls.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/core/widgets/ai_map_popup.dart';
import 'package:travel_memoir/core/constants/korea/sgg_code_map.dart';

class DomesticMapPage extends StatefulWidget {
  const DomesticMapPage({super.key});

  @override
  State<DomesticMapPage> createState() => DomesticMapPageState();
}

class DomesticMapPageState extends State<DomesticMapPage>
    with AutomaticKeepAliveClientMixin {
  MapboxMap? _map;

  @override
  bool get wantKeepAlive => true;

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

    // --- 광역시 및 특별시 추가 (색칠 누락 해결) ---
    // 서울특별시
    "11000": [
      "11110",
      "11140",
      "11170",
      "11200",
      "11215",
      "11230",
      "11260",
      "11290",
      "11305",
      "11320",
      "11350",
      "11380",
      "11410",
      "11440",
      "11470",
      "11500",
      "11530",
      "11545",
      "11560",
      "11590",
      "11620",
      "11650",
      "11680",
      "11710",
      "11740",
    ],
    // 부산광역시
    "26000": [
      "26110",
      "26140",
      "26170",
      "26200",
      "26230",
      "26260",
      "26290",
      "26320",
      "26350",
      "26380",
      "26410",
      "26440",
      "26470",
      "26500",
      "26530",
      "26710",
    ],
    // 대구광역시
    "27000": [
      "27110",
      "27140",
      "27170",
      "27200",
      "27230",
      "27260",
      "27290",
      "27710",
      "27720",
    ],
    // 인천광역시
    "28000": [
      "28110",
      "28140",
      "28170",
      "28185",
      "28200",
      "28237",
      "28245",
      "28260",
      "28710",
      "28720",
    ],
    // 광주광역시
    "29000": ["29110", "29140", "29155", "29170", "29200"],
    // 대전광역시
    "30000": ["30110", "30140", "30170", "30200", "30230"],
    // 울산광역시
    "31000": ["31110", "31140", "31170", "31200", "31710"],
    // 세종특별자치시
    "36110": ["36110"],
  };

  Future<void> refreshData() async {
    if (_map != null) {
      await _drawMapData();
    }
  }

  String _toHex(Color color) =>
      '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: MapWidget(
        styleUri: "mapbox://styles/hanajungjun/cmjztbzby003i01sth91eayzw",
        cameraOptions: CameraOptions(
          center: Point(coordinates: Position(127.8, 36.3)),
          zoom: 5.2,
        ),
        onMapCreated: (map) async {
          _map = map;
          try {
            await map.setBounds(
              CameraBoundsOptions(
                bounds: CoordinateBounds(
                  southwest: Point(coordinates: Position(124.0, 32.5)),
                  northeast: Point(coordinates: Position(131.2, 40.0)),
                  infiniteBounds: false,
                ),
                minZoom: 5.1,
                maxZoom: 12.0,
              ),
            );
            await map.setCamera(
              CameraOptions(
                center: Point(coordinates: Position(129.5, 36.3)),
                zoom: 5.2,
              ),
            );
            await map.gestures.updateSettings(
              GesturesSettings(rotateEnabled: false, pitchEnabled: false),
            );
          } catch (e) {
            debugPrint('❌ [BOUNDS ERROR] $e');
          }
        },
        onStyleLoadedListener: (data) async {
          await Future.delayed(const Duration(milliseconds: 120));
          await _drawMapData();
        },
        onTapListener: (context) => _onMapTap(context),
      ),
    );
  }

  Future<void> _drawMapData() async {
    final style = _map?.style;
    if (style == null) return;

    try {
      await style.setProjection(
        StyleProjection(name: StyleProjectionName.mercator),
      );
      await _localizeLabels(style);

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final travels = await Supabase.instance.client
          .from('travels')
          .select('region_id, is_completed, map_image_url')
          .eq('user_id', user.id)
          .eq('travel_type', 'domestic');

      final Set<String> allSgg = {};
      final Set<String> completedSgg = {};

      for (final t in travels) {
        final regId = t['region_id']?.toString() ?? '';
        final codeInfo = SggCodeMap.fromRegionId(regId);
        // 🔍 로그 추가: 변환된 SGG_CD 확인
        debugPrint(
          '⚙️ [MAP_DEBUG] region_id: $regId -> sggCd: ${codeInfo.sggCd}',
        );
        if (codeInfo.sggCd != null) {
          final sgg = codeInfo.sggCd!;
          allSgg.add(sgg);
          if (t['is_completed'] == true) completedSgg.add(sgg);

          if (majorCityMapping.containsKey(sgg)) {
            allSgg.addAll(majorCityMapping[sgg]!);
            if (t['is_completed'] == true)
              completedSgg.addAll(majorCityMapping[sgg]!);
          }
        }
      }

      // 🔍 로그 추가: 최종적으로 맵에 그릴 코드 목록 확인
      debugPrint('🎨 [MAP_DEBUG] 최종 그릴 SGG 목록: $allSgg');
      debugPrint('✅ [MAP_DEBUG] 완료된 SGG 목록: $completedSgg');

      final rawSig = await rootBundle.loadString(_sigGeoJson);
      await _rmLayer(style, _visitedSigLayer);
      await _rmSource(style, _sigSourceId);

      await style.addSource(GeoJsonSource(id: _sigSourceId, data: rawSig));
      await style.addLayer(
        FillLayer(id: _visitedSigLayer, sourceId: _sigSourceId),
      );

      await style.setStyleLayerProperty(_visitedSigLayer, 'filter', [
        'in',
        ['get', 'SGG_CD'],
        ['literal', allSgg.toList()],
      ]);

      // 🎨 [색상 수정] AppColors 시스템 적용
      final doneColor = _toHex(AppColors.travelingBlue); // 국내 완료 (황토색 인장)
      final activeColor = _toHex(AppColors.mapActiveFill); // 국내 진행중 (연한 레드)

      final colorExpr = completedSgg.isEmpty
          ? activeColor
          : [
              'case',
              [
                'in',
                ['get', 'SGG_CD'],
                ['literal', completedSgg.toList()],
              ],
              doneColor,
              activeColor,
            ];

      await style.setStyleLayerProperty(
        _visitedSigLayer,
        'fill-color',
        colorExpr,
      );
      await style.setStyleLayerProperty(_visitedSigLayer, 'fill-opacity', 0.8);
    } catch (e) {
      debugPrint('❌ [MAP DRAW ERROR] $e');
    }
  }

  Future<void> _onMapTap(MapContentGestureContext context) async {
    final map = _map;
    if (map == null) return;

    try {
      final screen = await map.pixelForCoordinate(context.point);
      final features = await map.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screen),
        RenderedQueryOptions(layerIds: [_visitedSigLayer]),
      );

      if (features.isEmpty) return;

      final props =
          features.first?.queriedFeature.feature['properties'] as Map?;
      if (props == null) return;

      final sggCode = props['SGG_CD']?.toString() ?? '';
      String lookup = sggCode;
      majorCityMapping.forEach((parent, children) {
        if (children.contains(sggCode)) lookup = parent;
      });

      final regId = SggCodeMap.getRegionIdFromSggCd(lookup);
      if (regId.isNotEmpty) _handlePopup(regId);
    } catch (e) {
      debugPrint('❌ [MAP TAP ERROR] $e');
    }
  }

  void _handlePopup(String regId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // 🎯 [로직 수정] 리스트로 받아 406 에러 방지 + created_at 최신순 정렬
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
        // 🎯 [수정] 현재 앱 언어 확인
        final String langCode = context.locale.languageCode;
        final bool isEn = langCode == 'en';

        // 🎯 [핵심] 언어에 따른 지역명 조합 로직
        String displayRegionName = '';
        if (isEn) {
          final String regIdStr = res['region_id']?.toString() ?? '';
          // 'KR_GB_BONGHWA' -> 'BONGHWA'
          displayRegionName = regIdStr.contains('_')
              ? regIdStr.split('_').last.toUpperCase()
              : res['region_name'].toString().toUpperCase();
        } else {
          // 한국어: "경상북도 봉화"
          displayRegionName = "${res['province']} ${res['region_name']}";
        }
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
              //  regionName:"${res['province'].toString().tr()} ${res['region_name'].toString().tr()}",
              regionName: displayRegionName,
              summary: res['ai_cover_summary'] ?? "no_memories_recorded".tr(),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [MAP POPUP ERROR] $e');
    }
  }

  Future<void> _localizeLabels(StyleManager style) async {
    final lang = context.locale.languageCode;
    final layers = await style.getStyleLayers();
    for (var l in layers) {
      if (l != null && (l.id.contains('label') || l.id.contains('place'))) {
        try {
          await style.setStyleLayerProperty(l.id, 'text-field', [
            'get',
            'name_$lang',
          ]);
        } catch (_) {}
      }
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
