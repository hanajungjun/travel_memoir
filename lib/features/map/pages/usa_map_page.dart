import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/core/widgets/ai_map_popup.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';

class UsaMapPage extends StatefulWidget {
  final bool isReadOnly;
  const UsaMapPage({super.key, this.isReadOnly = false});

  @override
  State<UsaMapPage> createState() => _UsaMapPageState();
}

class _UsaMapPageState extends State<UsaMapPage> {
  MapboxMap? _map;
  bool _isReadyToDisplay = false;
  Timer? _failsafeTimer;

  static const _usaSourceId = 'usa-standard-source';
  static const _usaFillLayer = 'usa-fill-layer';
  static const _usaLabelLayer = 'usa-label-layer';
  // ✅ 꼼수 없는 '정상 좌표' 제이슨을 쓰세요.
  static const _usaGeoJson = 'assets/geo/processed/usa_states_standard.json';

  @override
  void initState() {
    super.initState();
    _failsafeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isReadyToDisplay)
        setState(() => _isReadyToDisplay = true);
    });
  }

  @override
  void dispose() {
    _failsafeTimer?.cancel();
    super.dispose();
  }

  // 📍 멀리 있는 알래스카/하와이로 슉 날아가는 함수
  void _moveTo(double lat, double lng, double zoom) {
    _map?.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: zoom,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey("usa_standard_map"),
            styleUri: MapboxStyles.LIGHT, // 배경이 꽉 차 보여서 맛탱이 안 가 보임
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(-98.57, 39.82)),
              zoom: 3.0,
            ),
            onMapCreated: (map) => _map = map,
            onStyleLoadedListener: _onStyleLoaded,
            onTapListener: widget.isReadOnly ? null : _onMapTap,
          ),

          // 📍 우측 하단 지역 이동 버튼 (알래스카 찾기 고생 끝)
          Positioned(
            bottom: 30,
            right: 15,
            child: Column(
              children: [
                _navBtn("본토", 39.82, -98.57, 3.0),
                const SizedBox(height: 8),
                _navBtn("알래스카", 64.20, -149.49, 3.0),
                const SizedBox(height: 8),
                _navBtn("하와이", 20.79, -156.33, 6.0),
              ],
            ),
          ),

          if (!_isReadyToDisplay)
            Container(
              color: Colors.white,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _navBtn(String label, double lat, double lng, double zoom) {
    return ElevatedButton(
      onPressed: () => _moveTo(lat, lng, zoom),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.9),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData data) async {
    if (_map == null) return;
    await _drawUsaLayers();
    if (mounted) setState(() => _isReadyToDisplay = true);
  }

  Future<void> _drawUsaLayers() async {
    final style = _map!.style;
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final travels = await Supabase.instance.client
          .from('travels')
          .select('region_name, is_completed')
          .eq('user_id', user?.id ?? '')
          .eq('country_code', 'US');

      // ✅ [Object 에러 해결]
      final List<Map<String, dynamic>> dataList =
          List<Map<String, dynamic>>.from(travels);
      final Set<String> completedStates = dataList
          .where((t) => t['is_completed'] == true)
          .map((t) => t['region_name'].toString())
          .toSet();

      final usaJson = await rootBundle.loadString(_usaGeoJson);

      if (await style.styleSourceExists(_usaSourceId)) {
        await style.removeStyleLayer(_usaFillLayer);
        await style.removeStyleLayer(_usaLabelLayer);
        await style.removeStyleSource(_usaSourceId);
      }

      await style.addSource(GeoJsonSource(id: _usaSourceId, data: usaJson));

      // 1. 색칠
      await style.addLayer(
        FillLayer(id: _usaFillLayer, sourceId: _usaSourceId),
      );
      await style.setStyleLayerProperty(_usaFillLayer, 'fill-color', [
        'case',
        [
          'in',
          ['get', 'name'],
          ['literal', completedStates.toList()],
        ],
        '#${AppColors.mapOverseaVisitedFill.value.toRadixString(16).substring(2).toUpperCase()}',
        '#FFFFFF',
      ]);

      // 2. 이름 (중복 방지)
      await style.addLayer(
        SymbolLayer(id: _usaLabelLayer, sourceId: _usaSourceId),
      );
      await style.setStyleLayerProperty(_usaLabelLayer, 'text-field', [
        'get',
        'name',
      ]);
      await style.setStyleLayerProperty(_usaLabelLayer, 'text-size', 10);
      await style.setStyleLayerProperty(
        _usaLabelLayer,
        'text-padding',
        30,
      ); // 🎯 알래스카 이름 도배 해결
      await style.setStyleLayerProperty(
        _usaLabelLayer,
        'text-allow-overlap',
        false,
      );
    } catch (e) {
      debugPrint('❌ 그리기 에러: $e');
    }
  }

  Future<void> _onMapTap(MapContentGestureContext ctx) async {
    final features = await _map!.queryRenderedFeatures(
      RenderedQueryGeometry.fromScreenCoordinate(
        await _map!.pixelForCoordinate(ctx.point),
      ),
      RenderedQueryOptions(layerIds: [_usaFillLayer]),
    );
    if (features.isEmpty) return;
    final name =
        (features.first?.queriedFeature.feature['properties'] as Map?)?['name']
            ?.toString();
    if (name != null) _showUsaAiPopup(name);
  }

  void _showUsaAiPopup(String stateName) async {
    final user = Supabase.instance.client.auth.currentUser;
    final res = await Supabase.instance.client
        .from('travels')
        .select()
        .eq('user_id', user?.id ?? '')
        .eq('country_code', 'US')
        .eq('region_name', stateName)
        .maybeSingle();
    final data = res as Map<String, dynamic>?;
    if (data == null || data['is_completed'] != true) return;

    showGeneralDialog(
      context: context,
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (_, anim, __, ___) => Opacity(
        opacity: anim.value,
        child: AiMapPopup(
          imageUrl: data['map_image_url'] ?? "",
          regionName: stateName,
          summary: data['ai_cover_summary'] ?? 'remote_memory_placeholder'.tr(),
        ),
      ),
    );
  }
}
