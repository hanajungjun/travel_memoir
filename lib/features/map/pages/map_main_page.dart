import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:travel_memoir/features/map/pages/domestic_map_page.dart';
import 'package:travel_memoir/features/map/pages/global_map_page.dart';

class MapMainPage extends StatefulWidget {
  final int? initialIndex;
  final String travelId;

  const MapMainPage({super.key, required this.travelId, this.initialIndex});

  @override
  State<MapMainPage> createState() => _MapMainPageState();
}

class _MapMainPageState extends State<MapMainPage> {
  int? _index;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_index == null) {
      // ✅ 기본적으로 해외지도(0번)가 먼저 뜨도록 설정
      _index = widget.initialIndex ?? 0;
    }
  }

  void _move(int i) {
    if (!mounted || _index == i) return;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    if (_index == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('travel_map'.tr()),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // 🗺️ 탭 선택 영역 (해외를 왼쪽으로 배치)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // ✈️ [왼쪽 탭] 해외지도 (인덱스 0)
                _Tab(
                  label: 'overseas'.tr(),
                  selected: _index == 0,
                  onTap: () => _move(0),
                ),
                // 🇰🇷 [오른쪽 탭] 국내지도 (인덱스 1)
                _Tab(
                  label: 'korea'.tr(),
                  selected: _index == 1,
                  onTap: () => _move(1),
                ),
              ],
            ),
          ),

          // 🗺️ 지도 표시 영역
          Expanded(
            child: IndexedStack(
              index: _index!,
              children: const [
                // ✅ 인덱스 0번: 해외지도
                GlobalMapPage(key: ValueKey('GlobalMap_Main')),
                // ✅ 인덱스 1번: 국내지도
                DomesticMapPage(key: ValueKey('DomesticMap_Main')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 🎨 커스텀 탭 위젯 (기존과 동일)
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
