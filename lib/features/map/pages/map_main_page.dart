import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/features/map/pages/domestic_map_page.dart';
import 'package:travel_memoir/features/map/pages/global_map_page.dart';
import 'package:travel_memoir/features/my/pages/map_management/map_management_page.dart';

/**
 * 📱 Screen ID : MAP_MAIN_PAGE
 * 📝 Name      : 지도 통합 메인 화면
 * 🛠 Feature   : 
 * - 활성 지도 설정(active_maps)에 따른 동적 탭 구성
 * - travelType(domestic/overseas) 기반 초기 탭 자동 포커싱
 * - 지도 관리 페이지(MapManagementPage) 연동 및 설정 실시간 반영
 * * [ UI Structure ]
 * ----------------------------------------------------------
 * map_main_page.dart (Scaffold)
 * ├── AppBar [Title: travel_map / Action: Settings]
 * ├── Column (Body)
 * │    ├── _Tab (Custom Stateless Widget) [세계/한국 탭 스위치]
 * │    └── IndexedStack [지도 컨텐츠 영역]
 * │         ├── global_map_page.dart   [세계 지도]
 * │         └── domestic_map_page.dart [한국 지도]
 * └── map_management_page.dart         [지도 관리 설정 - Push]
 * ----------------------------------------------------------
 */

class MapMainPage extends StatefulWidget {
  final String travelId;
  final String travelType; // domestic / overseas / usa

  const MapMainPage({
    super.key,
    required this.travelId,
    required this.travelType,
  });

  @override
  State<MapMainPage> createState() => _MapMainPageState();
}

class _MapMainPageState extends State<MapMainPage> {
  final String _userId = Supabase.instance.client.auth.currentUser!.id;

  int _currentIndex = 0;
  bool _loading = true;

  /// 활성화된 지도 ID
  /// world = 세계 / ko = 한국
  List<String> _activeMapIds = ['world', 'ko'];

  @override
  void initState() {
    super.initState();
    _loadActiveMaps();
  }

  /// 사용자 설정에서 활성 지도 불러오기
  Future<void> _loadActiveMaps() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('active_maps')
          .eq('auth_uid', _userId)
          .maybeSingle();

      if (res != null && res['active_maps'] != null) {
        _activeMapIds = List<String>.from(res['active_maps']);
      }
    } catch (e) {
      debugPrint('❌ [MapMainPage] loadActiveMaps error: $e');
    } finally {
      if (mounted) {
        _buildInitialIndex(); // ⭐ travelType 기준 초기 탭 결정
        setState(() => _loading = false);
      }
    }
  }

  /// ⭐ travelType + activeMaps 기준으로 초기 탭 결정
  void _buildInitialIndex() {
    _currentIndex = 0;

    // 실제 탭 생성 순서와 동일
    final List<String> order = [];
    if (_activeMapIds.contains('world')) order.add('world');
    if (_activeMapIds.contains('ko')) order.add('ko');

    if (widget.travelType == 'domestic') {
      final koIndex = order.indexOf('ko');
      if (koIndex != -1) _currentIndex = koIndex;
    } else if (widget.travelType == 'usa' || widget.travelType == 'overseas') {
      final worldIndex = order.indexOf('world');
      if (worldIndex != -1) _currentIndex = worldIndex;
    }

    debugPrint(
      '🧭 [MapMainPage] travelType=${widget.travelType}, '
      'activeMaps=$_activeMapIds, initialIndex=$_currentIndex',
    );
  }

  void _move(int i) {
    if (!mounted || _currentIndex == i) return;
    setState(() => _currentIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    /// ⭐ 동적 탭 구성
    final List<Map<String, dynamic>> configs = [];

    if (_activeMapIds.contains('world')) {
      configs.add({
        'id': 'world',
        'label': 'overseas'.tr(),
        'page': const GlobalMapPage(key: ValueKey('GlobalMap_Main')),
      });
    }

    if (_activeMapIds.contains('ko')) {
      configs.add({
        'id': 'ko',
        'label': 'korea'.tr(),
        'page': const DomesticMapPage(key: ValueKey('DomesticMap_Main')),
      });
    }

    /// 🛡️ 활성 지도 하나도 없을 때 방어
    if (configs.isEmpty) {
      return const Scaffold(body: Center(child: Text('활성화된 지도가 없습니다')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('travel_map'.tr()),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MapManagementPage()),
              );
              _loadActiveMaps(); // 설정 복귀 후 재계산
            },
          ),
        ],
      ),
      body: Column(
        children: [
          /// 탭 영역 (2개 이상일 때만)
          if (configs.length > 1)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: List.generate(configs.length, (index) {
                  return _Tab(
                    label: configs[index]['label'],
                    selected: _currentIndex == index,
                    onTap: () => _move(index),
                  );
                }),
              ),
            ),

          /// 지도 영역
          Expanded(
            child: IndexedStack(
              index: configs.length > 1 ? _currentIndex : 0,
              children: configs.map((e) => e['page'] as Widget).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? Colors.black : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
