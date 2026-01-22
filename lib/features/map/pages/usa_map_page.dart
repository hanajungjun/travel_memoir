import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';

class UsaMapPage extends StatefulWidget {
  final bool isReadOnly;
  const UsaMapPage({super.key, this.isReadOnly = false});

  @override
  State<UsaMapPage> createState() => _UsaMapPageState();
}

class _UsaMapPageState extends State<UsaMapPage> {
  MapboxMap? _map;
  bool _init = false;
  bool _ready = false;

  static const _usaSource = 'usa-states-source';
  static const _usaFill = 'usa-states-fill';
  static const _usaGeo = 'assets/geo/processed/usa_states_standard.json';

  final _mainland = CameraOptions(
    center: Point(coordinates: Position(-98.5, 39.5)),
    zoom: 2.5,
  );
  final _alaska = CameraOptions(
    center: Point(coordinates: Position(-152.0, 63.0)),
    zoom: 2.2,
  );
  final _hawaii = CameraOptions(
    center: Point(coordinates: Position(-157.5, 20.5)),
    zoom: 5.5,
  );

  String _hex(Color c) =>
      '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  void _moveCamera(CameraOptions options) {
    _map?.flyTo(options, MapAnimationOptions(duration: 800));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapWidget(
          styleUri: "mapbox://styles/hanajungjun/cmjztbzby003i01sth91eayzw",
          cameraOptions: _mainland,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
            Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
          },
          onMapCreated: (map) => _map = map,
          onStyleLoadedListener: _onStyleLoaded,
        ),
        if (!_ready)
          const ColoredBox(
            color: Colors.white,
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_ready)
          Positioned(
            top: 10,
            left: 10,
            child: Row(
              children: [
                _buildMapButton('Mainland', () => _moveCamera(_mainland)),
                const SizedBox(width: 6),
                _buildMapButton('Alaska', () => _moveCamera(_alaska)),
                const SizedBox(width: 6),
                _buildMapButton('Hawaii', () => _moveCamera(_hawaii)),
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

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    if (_init || _map == null) return;
    _init = true;

    // ✅ 1. 안정적인 로드를 위해 지연 시간 추가
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      await _map!.style.setProjection(
        StyleProjection(name: StyleProjectionName.mercator),
      );
    } catch (e) {
      debugPrint('Projection error: $e');
    }

    await _localizeLabels();
    await _drawVisitedStates();

    if (mounted) setState(() => _ready = true);
  }

  Future<void> _drawVisitedStates() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _map == null) return;

    final travels = await Supabase.instance.client
        .from('travels')
        .select('region_name, is_completed')
        .eq('user_id', user.id)
        .eq('travel_type', 'usa');

    final Set<String> visitedStates = {};
    final Set<String> completedStates = {};

    for (final t in (travels as List)) {
      final stateName = t['region_name']?.toString();
      if (stateName != null) {
        // ✅ 2. DB 데이터를 대문자로 처리하여 세트에 저장
        final upperName = stateName.toUpperCase();
        visitedStates.add(upperName);
        if (t['is_completed'] == true) completedStates.add(upperName);
      }
    }

    final style = _map!.style;
    final usaJson = await rootBundle.loadString(_usaGeo);

    if (await style.styleSourceExists(_usaSource)) {
      await style.removeStyleSource(_usaSource);
    }
    if (await style.styleLayerExists(_usaFill)) {
      await style.removeStyleLayer(_usaFill);
    }

    await style.addSource(GeoJsonSource(id: _usaSource, data: usaJson));
    await style.addLayer(FillLayer(id: _usaFill, sourceId: _usaSource));

    final doneColor = _hex(AppColors.mapOverseaVisitedFill);
    final activeColor = _hex(const Color(0xFFE74C3C).withOpacity(0.4));

    // ✅ 3. GeoJSON의 NAME도 대문자로 변환(['upcase'])하여 비교
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
      doneColor,
      activeColor,
    ]);
    await style.setStyleLayerProperty(_usaFill, 'fill-opacity', 0.6);
  }

  Future<void> _localizeLabels() async {
    final lang = context.locale.languageCode;
    try {
      if (await _map!.style.styleLayerExists('state-label')) {
        await _map!.style.setStyleLayerProperty(
          'state-label',
          'text-field',
          lang == 'ko' ? ['get', 'name_ko'] : ['get', 'name_en'],
        );
      }
    } catch (_) {}
  }
}
