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
        //padding: const EdgeInsets.only(bottom: 5), // ✅ 살짝 줄임
        padding: const EdgeInsets.only(
          top: 5,
        ), // ✅ bottom 대신 top 패딩을 주면 아래로 내려옵니다.
        child: Image.asset(iconAsset, width: 22, height: 22),
      ),
      activeIcon: Padding(
        // padding: const EdgeInsets.only(bottom: 5), // ✅ 살짝 줄임
        padding: const EdgeInsets.only(top: 5), // ✅ 여기도 동일하게 적용
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Image.asset(iconAsset, width: 22, height: 22),
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                width: 10, // 🎯 알림 점 크기도 살짝 축소
                height: 10,
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
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
        child: Container(
          //height: 70, // ✅ 네비 버튼 영역 높이 고정
          height: MediaQuery.of(context).padding.bottom + 70,
          color: AppColors.background, // ✅ 여기서 배경색 지정
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabSelected,
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.background,
            elevation: 0,

            // ✅ 폰트 크기 통일
            selectedFontSize: 12,
            unselectedFontSize: 12,

            // ✅ 글자 색상 통일
            selectedItemColor: AppColors.textColor01,
            unselectedItemColor: AppColors.textColor01,

            // ✅ 라벨 스타일 통일
            selectedLabelStyle: const TextStyle(
              height: 1.7,
              fontWeight: FontWeight.w400,
            ),
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
    );
  }
}
