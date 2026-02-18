import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/storage_urls.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/core/widgets/ai_map_popup.dart';
import 'package:travel_memoir/core/utils/travel_utils.dart'; // 경로는 맞게 수정
import 'package:travel_memoir/core/constants/korea/sgg_code_map.dart';

class DomesticMapPage extends StatefulWidget {
  const DomesticMapPage({super.key});

  @override
  State<DomesticMapPage> createState() => DomesticMapPageState();
}

class DomesticMapPageState extends State<DomesticMapPage>
    with AutomaticKeepAliveClientMixin {
  MapboxMap? _map;
  String? _cachedSigGeoJson; // ✅ GeoJSON 캐싱

  @override
  bool get wantKeepAlive => true;

  static const _sigSourceId = 'korea-sig-source';
  static const _visitedSigLayer = 'visited-sig-layer';
  static const _sigGeoJson = 'assets/geo/processed/korea_sig.geojson';

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
    // ✅ Scaffold 제거
    return MapWidget(
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
        await Future.delayed(const Duration(milliseconds: 300)); // ✅ 120 → 300
        await _drawMapData();
      },
      onTapListener: (context) => _onMapTap(context),
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

      // ✅ GeoJSON 캐싱 적용
      _cachedSigGeoJson ??= await rootBundle.loadString(_sigGeoJson);

      await _rmLayer(style, _visitedSigLayer);
      await _rmSource(style, _sigSourceId);

      await style.addSource(
        GeoJsonSource(id: _sigSourceId, data: _cachedSigGeoJson!),
      );
      await style.addLayer(
        FillLayer(id: _visitedSigLayer, sourceId: _sigSourceId),
      );

      await style.setStyleLayerProperty(_visitedSigLayer, 'filter', [
        'in',
        ['get', 'SGG_CD'],
        ['literal', allSgg.toList()],
      ]);

      final doneColor = _toHex(AppColors.travelingBlue);
      final activeColor = _toHex(AppColors.mapActiveFill);

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
      TravelUtils.majorCityMapping.forEach((parent, children) {
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
