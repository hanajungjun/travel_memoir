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

    // ✅ 위젯이 생성될 때 딱 한 번 실행
    if (_index == null) {
      final String lang = context.locale.languageCode;

      // 1. 인덱스 결정 (한국어면 0, 영어 등 그 외엔 1)
      _index = widget.initialIndex ?? (lang == 'ko' ? 0 : 1);

      // 2. 결정된 인덱스로 컨트롤러를 생성 (초기 페이지 고정)
      _controller = PageController(initialPage: _index!);

      debugPrint("🏁 [MapMainPage] 초기 설정 완료: 언어($lang) -> 인덱스($_index)");
    }
  }

  void _move(int i) {
    if (_index == i) return;
    setState(() => _index = i);
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
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
              onPageChanged: (i) => setState(() => _index = i),
              children: const [DomesticMapPage(), GlobalMapPage()],
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
