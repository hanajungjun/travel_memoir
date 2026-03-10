import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/env.dart';

class UsaMapPage extends StatefulWidget {
  final bool isReadOnly;
  const UsaMapPage({super.key, this.isReadOnly = false});

  @override
  State<UsaMapPage> createState() => UsaMapPageState();
}

class UsaMapPageState extends State<UsaMapPage> {
  final MapController _mapController = MapController();
  List<Polygon> _polygons = [];
  bool _ready = false;

  static const _usaGeo = 'assets/geo/processed/usa_states_standard.json';

  // ✅ 미국 주요 지역 좌표 설정
  final _mainland = const LatLng(39.5, -98.5);
  final _alaska = const LatLng(63.0, -152.0);
  final _hawaii = const LatLng(20.5, -157.5);

  @override
  void initState() {
    super.initState();
    _loadAndDrawStates();
  }

  // ✅ TravelMapPager 등 외부에서 부르는 새로고침 함수
  Future<void> refreshData() async {
    if (!mounted) return;
    await _loadAndDrawStates();
  }

  void _moveCamera(LatLng point, double zoom) {
    _mapController.move(point, zoom);
  }

  Future<void> _loadAndDrawStates() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // 1. 수퍼베이스에서 미국 여행 데이터 가져오기
      final travels = await Supabase.instance.client
          .from('travels')
          .select('region_name, is_completed')
          .eq('user_id', user.id)
          .eq('travel_type', 'usa');

      final Set<String> visitedStates = {};
      final Set<String> completedStates = {};

      for (final t in travels) {
        final stateName = t['region_name']?.toString().toUpperCase();
        if (stateName != null) {
          visitedStates.add(stateName);
          if (t['is_completed'] == true) completedStates.add(stateName);
        }
      }

      // 2. GeoJSON 파일 로드 및 파싱
      final jsonString = await rootBundle.loadString(_usaGeo);
      final data = json.decode(jsonString);
      final List<Polygon> newPolygons = [];

      // 색상 설정 (기존 형님 코드의 로직 유지)
      final doneColor = AppColors.mapOverseaVisitedFill.withOpacity(0.8);
      final activeColor = const Color(0xFFE74C3C).withOpacity(0.4);

      for (var feature in data['features']) {
        final name = feature['properties']['NAME'].toString().toUpperCase();
        if (!visitedStates.contains(name)) continue;

        final color = completedStates.contains(name) ? doneColor : activeColor;
        final geometry = feature['geometry'];

        // 폴리곤 및 멀티폴리곤 처리
        if (geometry['type'] == 'Polygon') {
          newPolygons.add(_buildPolygon(geometry['coordinates'], color));
        } else if (geometry['type'] == 'MultiPolygon') {
          for (var poly in geometry['coordinates']) {
            newPolygons.add(_buildPolygon(poly, color));
          }
        }
      }

      if (mounted) {
        setState(() {
          _polygons = newPolygons;
          _ready = true;
        });
      }
    } catch (e) {
      debugPrint('❌ [UsaMapPage] Error: $e');
    }
  }

  Polygon _buildPolygon(List coords, Color color) {
    final List list = coords[0] is List ? coords[0] : coords;
    return Polygon(
      points: list
          .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
          .toList(),
      color: color,
      borderStrokeWidth: 1,
      borderColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _mainland,
            initialZoom: 3.5,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://api.mapbox.com/styles/v1/{styleId}/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}',
              additionalOptions: {
                'styleId': 'hanajungjun/cmjztbzby003i01sth91eayzw',
                'accessToken': AppEnv.mapboxAccessToken,
              },
              tileSize: 256,
              tileDisplay: const TileDisplay.fadeIn(
                duration: Duration(milliseconds: 300),
              ),
            ),
            PolygonLayer(polygons: _polygons),
          ],
        ),
        // 로딩 스피너
        if (!_ready)
          const ColoredBox(
            color: Colors.white,
            child: Center(child: CircularProgressIndicator()),
          ),
        // ✅ 카메라 퀵 이동 버튼 (기존 기능 그대로!)
        if (_ready)
          Positioned(
            top: 10,
            left: 10,
            child: Row(
              children: [
                _buildMapButton('Mainland', () => _moveCamera(_mainland, 3.5)),
                const SizedBox(width: 6),
                _buildMapButton('Alaska', () => _moveCamera(_alaska, 3.0)),
                const SizedBox(width: 6),
                _buildMapButton('Hawaii', () => _moveCamera(_hawaii, 6.0)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMapButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
