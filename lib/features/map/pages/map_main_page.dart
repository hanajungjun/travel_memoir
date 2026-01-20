import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/features/map/pages/domestic_map_page.dart';
import 'package:travel_memoir/features/map/pages/global_map_page.dart';
import 'package:travel_memoir/features/my/pages/map_management/map_management_page.dart'; // ✅ 설정 페이지 추가

class MapMainPage extends StatefulWidget {
  final int? initialIndex;
  final String travelId;

  const MapMainPage({super.key, required this.travelId, this.initialIndex});

  @override
  State<MapMainPage> createState() => _MapMainPageState();
}

class _MapMainPageState extends State<MapMainPage> {
  final String _userId = Supabase.instance.client.auth.currentUser!.id;
  int _currentIndex = 0;

  // ✅ 활성화된 지도 ID 리스트 (초기값은 기본 제공 맵)
  List<String> _activeMapIds = ['world', 'ko'];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadActiveMaps(); // ✅ 페이지 진입 시 활성 맵 로드
  }

  /// ✅ 사용자의 활성화된 지도 목록 로드
  Future<void> _loadActiveMaps() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('active_maps')
          .eq('auth_uid', _userId) // ✅ auth_uid 컬럼 기준
          .maybeSingle();

      if (res != null && res['active_maps'] != null) {
        setState(() {
          _activeMapIds = List<String>.from(res['active_maps']);
        });
      }
    } catch (e) {
      debugPrint('❌ [MapMainPage] Load Maps Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

    // 🎯 [핵심] activeMapIds에 따라 탭과 페이지를 동적으로 생성
    final List<Map<String, dynamic>> dynamicConfigs = [];

    // 1. 세계/미국 지도는 항상 포함 ('world')
    if (_activeMapIds.contains('world')) {
      dynamicConfigs.add({
        'label': 'overseas'.tr(),
        'page': const GlobalMapPage(key: ValueKey('GlobalMap_Main')),
      });
    }

    // 2. 한국 지도는 리스트에 'ko'가 있을 때만 추가 ✅
    if (_activeMapIds.contains('ko')) {
      dynamicConfigs.add({
        'label': 'korea'.tr(),
        'page': const DomesticMapPage(key: ValueKey('DomesticMap_Main')),
      });
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
              // ✅ 설정 페이지 갔다 오면 리스트 다시 불러오기
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MapManagementPage()),
              );
              _loadActiveMaps();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 🗺️ 탭 선택 영역: 탭이 2개 이상일 때만 노출
          if (dynamicConfigs.length > 1)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: List.generate(dynamicConfigs.length, (index) {
                  return _Tab(
                    label: dynamicConfigs[index]['label'],
                    selected: _currentIndex == index,
                    onTap: () => _move(index),
                  );
                }),
              ),
            ),

          // 🗺️ 지도 표시 영역
          Expanded(
            child: IndexedStack(
              // 탭이 하나면 무조건 0번 인덱스 노출
              index: dynamicConfigs.length > 1 ? _currentIndex : 0,
              children: dynamicConfigs
                  .map((config) => config['page'] as Widget)
                  .toList(),
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
