import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  static const _worldSourceId = 'world-country-source';
  static const _visitedCountryLayer = 'visited-country-layer';
  static const _borderCountryLayer = 'border-country-layer';
  static const _worldGeoJson = 'assets/geo/processed/world_countries.geojson';

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      // styleUri: "mapbox://styles/hanajungjun/cmjztbzby003i01sth91eayzw",
      cameraOptions: CameraOptions(
        center: Point(coordinates: Position(10.0, 20.0)),
        zoom: widget.isReadOnly ? 0.1 : 0.5,
      ),
      gestureRecognizers: widget.isReadOnly
          ? {}
          : {
              Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
              Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
            },
      onMapCreated: (map) async {
        _map = map;
        await map.gestures.updateSettings(
          GesturesSettings(pitchEnabled: false),
        );
        await map.setBounds(CameraBoundsOptions(minZoom: 0.0, maxZoom: 8.0));
      },
      onStyleLoadedListener: _onStyleLoaded,
      onTapListener: widget.isReadOnly ? null : (context) => _onMapTap(context),
    );
  }

  // =========================================================
  // 🖱️ 1. 해외 지도 클릭 핸들러
  // =========================================================
  Future<void> _onMapTap(MapContentGestureContext context) async {
    final map = _map;
    if (map == null) return;

    try {
      final screenCoordinate = await map.pixelForCoordinate(context.point);
      final features = await map.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screenCoordinate),
        RenderedQueryOptions(layerIds: [_visitedCountryLayer]),
      );

      if (features.isNotEmpty) {
        final props =
            features.first?.queriedFeature.feature['properties'] as Map?;
        if (props != null) {
          // GeoJSON 속성명 확인 (ISO_A2_EH)
          final String countryCode =
              props['ISO_A2_EH'] ?? props['iso_a2'] ?? '';
          final String countryName = props['NAME'] ?? props['name'] ?? '해외 지역';

          if (countryCode.isNotEmpty) {
            debugPrint('🌍 해외 클릭 감지: $countryName ($countryCode)');
            _showOverseasAiPopup(countryCode, countryName);
          }
        }
      }
    } catch (e) {
      debugPrint('❌ 해외 클릭 쿼리 에러: $e');
    }
  }

  // =========================================================
  // 🎨 2. AI 이미지 팝업 (완료된 여행 데이터만 조회)
  // =========================================================
  void _showOverseasAiPopup(String countryCode, String countryName) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('travels')
          .select(
            'map_image_url, country_name_ko, country_name_en, ai_cover_summary',
          )
          .eq('user_id', user.id)
          .eq('country_code', countryCode)
          .eq('is_completed', true) // ✅ 완료된 여행만 필터링
          .not('map_image_url', 'is', null)
          .order('completed_at', ascending: false) // 최신 완료순
          .limit(1)
          .maybeSingle();

      if (response == null || response['map_image_url'] == null) {
        debugPrint('ℹ️ $countryName 지역의 완료된 기록이 없습니다.');
        return;
      }

      if (!mounted) return;

      // 🌐 시스템 언어 확인
      final bool isKo =
          View.of(context).platformDispatcher.locale.languageCode == 'ko';

      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: "Global AI Map",
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
        transitionBuilder: (context, anim1, anim2, child) {
          final curvedValue = Curves.easeOutBack.transform(anim1.value);

          // 다국어 이름 결정
          final displayRegion =
              (isKo
                  ? response['country_name_ko']
                  : response['country_name_en']) ??
              countryName;

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX((1 - curvedValue) * 1.5),
            alignment: Alignment.bottomCenter,
            child: Opacity(
              opacity: anim1.value.clamp(0.0, 1.0),
              child: AiMapPopup(
                imageUrl: response['map_image_url'],
                regionName: displayRegion,
                summary: response['ai_cover_summary'] ?? "먼 곳에서 온 기록.",
              ),
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('❌ 해외 데이터 조회 에러: $e');
    }
  }

  // =========================================================
  // 🗺️ 3. 스타일 로드 및 렌더링
  // =========================================================
  Future<void> _onStyleLoaded(StyleLoadedEventData data) async {
    if (_styleInitialized) return;
    _styleInitialized = true;

    final map = _map;
    if (map == null) return;
    final style = map.style;

    // 2D 평면 고정 (Mercator)
    try {
      await style.setProjection(
        StyleProjection(name: StyleProjectionName.mercator),
      );
    } catch (e) {
      debugPrint('⚠️ Projection 에러: $e');
    }

    // 기본 레이어 한글화
    try {
      final layers = await style.getStyleLayers();
      for (var layer in layers) {
        final id = layer?.id;
        if (id != null && (id.contains('label') || id.contains('place'))) {
          await style.setStyleLayerProperty(
            id,
            'text-field',
            '["get", "name_ko"]',
          );
        }
      }
    } catch (_) {}

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // ✅ [수정] 완료된 해외 여행 데이터만 직접 가져오기
    final response = await Supabase.instance.client
        .from('travels')
        .select('country_code, country_name_ko, country_name_en')
        .eq('user_id', user.id)
        .eq('travel_type', 'overseas')
        .eq('is_completed', true); // 🔥 등록만 한 여행은 제외

    final List<Map<String, dynamic>> travels = List<Map<String, dynamic>>.from(
      response,
    );

    final worldGeoJson = await rootBundle.loadString(_worldGeoJson);

    // 기존 자원 정리
    await _rmLayer(style, _visitedCountryLayer);
    await _rmLayer(style, _borderCountryLayer);
    await _rmSource(style, _worldSourceId);

    // GeoJSON 소스 추가
    await style.addSource(
      GeoJsonSource(id: _worldSourceId, data: worldGeoJson),
    );

    // 방문한 국가(완료된 여행지) 색칠
    if (travels.isNotEmpty) {
      final Set<String> countryCodes = travels
          .map((t) => t['country_code']?.toString())
          .whereType<String>()
          .toSet();

      await style.addLayer(
        FillLayer(
          id: _visitedCountryLayer,
          sourceId: _worldSourceId,
          filter: [
            'in',
            ['get', 'ISO_A2_EH'], // GeoJSON의 국가코드 필드와 매칭
            ['literal', countryCodes.toList()],
          ],
          fillColor: AppColors.mapOverseaVisitedFill.value,
          fillOpacity: 0.6,
        ),
      );
    }

    // 국경선 추가
    final borderLayer = LineLayer(
      id: _borderCountryLayer,
      sourceId: _worldSourceId,
    );
    borderLayer.lineColor = 0xFF333333;
    borderLayer.lineWidth = 0.5;
    await style.addLayer(borderLayer);

    // 마커 생성 로직 (Geocoding 활용)
    final pointManager = await map.annotations.createPointAnnotationManager();
    Map<String, double>? lastLocation;

    for (final travel in travels) {
      // 한국어 이름을 우선으로 좌표 찾기
      final countryName =
          travel['country_name_ko'] ?? travel['country_name_en'];
      if (countryName == null) continue;

      try {
        final res = await OverseasTravelService.geocode(query: countryName);
        if (res != null && res['found'] == true) {
          final lat = res['lat'] as double;
          final lng = res['lng'] as double;
          await pointManager.create(
            PointAnnotationOptions(
              geometry: Point(coordinates: Position(lng, lat)),
              iconImage: 'marker-15',
              iconSize: 1.6,
            ),
          );
          lastLocation = {'lat': lat, 'lng': lng};
        }
      } catch (_) {}
    }

    // 마지막 방문지로 카메라 이동
    if (!widget.isReadOnly && lastLocation != null) {
      await map.easeTo(
        CameraOptions(
          center: Point(
            coordinates: Position(lastLocation['lng']!, lastLocation['lat']!),
          ),
          zoom: 1.5,
        ),
        MapAnimationOptions(duration: 1500),
      );
    }
  }

  // --- 레이어/소스 제거 헬퍼 함수 ---
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
