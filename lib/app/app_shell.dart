import 'package:flutter/material.dart';

import '../features/home/pages/home_page.dart';
import '../features/travel_info/pages/travel_info_page.dart';
import '../features/intro/pages/intro_page.dart';

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
    HomePage(
      onGoToTravel: () => _onTabSelected(1), // 홈 → 여행 탭 이동
    ),
    const TravelInfoPage(), // 여행 목록 / 여행 추가
    const Center(
      child: Text('기록을 선택해주세요'), // 기록 탭 (임시)
    ),
    const IntroPage(), // 마이 페이지
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
