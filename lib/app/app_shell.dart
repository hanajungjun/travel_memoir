import 'package:flutter/material.dart';

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

  late final List<Widget> _pages = [
    HomePage(onGoToTravel: () => _onTabSelected(1)),
    const TravelInfoPage(),
    const RecordTabPage(),
    const MyPage(),
  ];

  // 커스텀 메뉴 아이템 빌더
  BottomNavigationBarItem _buildMenuItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    return BottomNavigationBarItem(
      // 1. 선택되지 않았을 때 (기본 회색 아이콘)
      icon: Icon(icon),

      // 2. 선택되었을 때 (아이콘 색상은 그대로 검정, 파란 점만 추가)
      activeIcon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: Colors.black87), // 아이콘 색상을 파란색이 아닌 검정색으로 고정
          Positioned(
            top: -2,
            right: -4,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF2196F3), // 오직 이 점만 파란색!
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
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
        type: BottomNavigationBarType.fixed,

        // 글자 색상 설정
        selectedItemColor: Colors.black87, // 선택된 글자도 검정색 계열로
        unselectedItemColor: Colors.grey,

        selectedFontSize: 12,
        unselectedFontSize: 12,

        items: [
          _buildMenuItem(icon: Icons.home_outlined, label: '홈', index: 0),
          _buildMenuItem(icon: Icons.work_outline, label: '여행', index: 1),
          _buildMenuItem(icon: Icons.menu_book, label: '기록', index: 2),
          _buildMenuItem(icon: Icons.person_outline, label: '마이', index: 3),
        ],
      ),
    );
  }
}
