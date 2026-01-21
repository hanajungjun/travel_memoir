import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
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

  // ✅ 메뉴 아이템: 높이가 줄어든 만큼 아이콘 크기와 여백도 미세하게 축소
  BottomNavigationBarItem _buildMenuItem({
    required String iconAsset,
    required String label,
  }) {
    return BottomNavigationBarItem(
      icon: Padding(
        padding: const EdgeInsets.only(bottom: 5), // ✅ 살짝 줄임
        child: Image.asset(iconAsset, width: 22, height: 22),
      ),
      activeIcon: Padding(
        padding: const EdgeInsets.only(bottom: 5), // ✅ 살짝 줄임
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Image.asset(
              iconAsset,
              width: 20,
              height: 20,
              color: AppColors.textColor01,
            ),
            Positioned(
              top: -3,
              right: -4,
              child: Container(
                width: 7, // 🎯 알림 점 크기도 살짝 축소
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
      label: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomePage(onGoToTravel: () => _onTabSelected(1)),
      const TravelInfoPage(),
      const RecordTabPage(),
      const MyPage(),
    ];

    return Scaffold(
      extendBody: true, // ✅ 이 줄 추가 (진짜 핵심)
      body: IndexedStack(index: _currentIndex, children: pages),

      // ✅ [하단 영역 슬림화 버전]
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          // 🎯 그림자(boxShadow)를 완전히 제거하여 매끄럽게 만듦
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          bottom: false,
          top: false,
          child: SizedBox(
            height: 45, // 🎯 64 -> 52로 높이 대폭 축소 (아이콘+텍스트 최소 영역)
            child: BottomNavigationBar(
              key: ValueKey(context.locale.toString()),
              currentIndex: _currentIndex,
              onTap: _onTabSelected,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent, // 컨테이너 색상 사용
              elevation: 0, // 🎯 기본 그림자 효과 완전히 제거
              selectedFontSize: 11, // 🎯 글자 크기 11 -> 10 축소
              unselectedFontSize: 11,
              selectedItemColor: AppColors.textColor01,
              unselectedItemColor: AppColors.textColor01.withOpacity(0.4),
              selectedLabelStyle: const TextStyle(
                height: 1.0,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(height: 1.0),
              items: [
                _buildMenuItem(
                  iconAsset: 'assets/icons/nav_home.png',
                  label: 'nav_home'.tr(),
                ),
                _buildMenuItem(
                  iconAsset: 'assets/icons/nav_travel.png',
                  label: 'nav_travel'.tr(),
                ),
                _buildMenuItem(
                  iconAsset: 'assets/icons/nav_record.png',
                  label: 'nav_record'.tr(),
                ),
                _buildMenuItem(
                  iconAsset: 'assets/icons/nav_my.png',
                  label: 'nav_my'.tr(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
