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
  late PageController _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_index == null) {
      final String lang = context.locale.languageCode;
      _index = widget.initialIndex ?? (lang == 'ko' ? 0 : 1);
      _controller = PageController(initialPage: _index!);
    }
  }

  void _move(int i) {
    // 🎯 [방어] 이미 화면이 꺼졌거나 인덱스가 같으면 실행 안 함
    if (!mounted || _index == i) return;

    setState(() => _index = i);
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose(); // 컨트롤러 먼저 닫고
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_index == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: Text('travel_map'.tr()), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _Tab(
                  label: 'korea'.tr(),
                  selected: _index == 0,
                  onTap: () => _move(0),
                ),
                _Tab(
                  label: 'overseas'.tr(),
                  selected: _index == 1,
                  onTap: () => _move(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _controller,
              // 🎯 [방어] 페이지가 바뀌었을 때도 화면이 살아있는지 확인
              onPageChanged: (i) {
                if (mounted) setState(() => _index = i);
              },
              children: const [DomesticMapPage(), GlobalMapPage()],
            ),
          ),
        ],
      ),
    );
  }
}

// _Tab 위젯은 기존과 동일 (생략 가능하나 구조 유지를 위해 포함)
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
