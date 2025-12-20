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

    /// ✅ 여행 탭 : 내가 다녀온 여행 리스트
    const TravelInfoPage(),

    /// ✅ 기록 탭 : 완료된 여행 아카이브
    const RecordTabPage(),

    const MyPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.card_travel), label: '여행'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: '기록'),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: '마이',
          ),
        ],
      ),
    );
  }
}
