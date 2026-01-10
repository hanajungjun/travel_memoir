import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/features/home/pages/home_page.dart';
import 'package:travel_memoir/features/record/pages/record_tab_page.dart';
import 'package:travel_memoir/features/travel_info/pages/travel_info_page.dart';
import 'package:travel_memoir/features/my/pages/my_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  // 커스텀 메뉴 아이템 빌더
  BottomNavigationBarItem _buildMenuItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    return BottomNavigationBarItem(
      icon: Icon(icon),
      activeIcon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: Colors.black87),
          Positioned(
            top: -2,
            right: -4,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF2196F3),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
      label: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 1. 페이지 리스트를 build 내부로 옮겨서 언어 변경 시 즉시 반영되도록 함
    final List<Widget> pages = [
      HomePage(onGoToTravel: () => _onTabSelected(1)),
      const TravelInfoPage(),
      const RecordTabPage(),
      const MyPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        // ✅ 2. [핵심] ValueKey 추가 - 언어(locale)가 바뀔 때마다 탭바를 새로 그림
        key: ValueKey(context.locale.toString()),
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black87,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: [
          _buildMenuItem(
            icon: Icons.home_outlined,
            label: 'nav_home'.tr(),
            index: 0,
          ),
          _buildMenuItem(
            icon: Icons.work_outline,
            label: 'nav_travel'.tr(),
            index: 1,
          ),
          _buildMenuItem(
            icon: Icons.menu_book,
            label: 'nav_record'.tr(),
            index: 2,
          ),
          _buildMenuItem(
            icon: Icons.person_outline,
            label: 'nav_my'.tr(),
            index: 3,
          ),
        ],
      ),
    );
  }
}
