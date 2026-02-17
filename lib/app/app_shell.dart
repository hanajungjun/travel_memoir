import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/features/home/pages/home_page.dart';
import 'package:travel_memoir/features/log/pages/record_tab_page.dart';
import 'package:travel_memoir/features/travel_list/pages/travel_list_page.dart';
import 'package:travel_memoir/features/my/pages/my_page.dart';
import 'package:travel_memoir/features/shop/page/shop_page.dart';
import 'package:flutter_svg/flutter_svg.dart'; // SVG 아이콘을 사용하기 위해 추가

/**
 * 📱 Screen ID: APP_SHELL
 * 📝 Name: 앱 메인 레이아웃 (Bottom Navigation)
 * 🛠 Feature: 5개 메인 탭 전환 관리, 하단바 슬림화 디자인 적용
 * 🎨 Design: 인덱스 0(홈) 아닐 때만 상단 보더라인 노출 분기 처리
 */

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
    // SVG 파일 여부 확인
    final isSvg = iconAsset.toLowerCase().endsWith('.svg');

    return BottomNavigationBarItem(
      icon: Padding(
        //padding: const EdgeInsets.only(bottom: 5), // ✅ 살짝 줄임
        padding: const EdgeInsets.only(
          top: 9,
          bottom: 0,
        ), // ✅ bottom 대신 top 패딩을 주면 아래로 내려옵니다.
        child: isSvg
            ? SvgPicture.asset(iconAsset, width: 18, height: 18)
            : Image.asset(iconAsset, width: 18, height: 18),
      ),
      activeIcon: Padding(
        // padding: const EdgeInsets.only(bottom: 5), // ✅ 살짝 줄임
        padding: const EdgeInsets.only(top: 9, bottom: 0), // ✅ 여기도 동일하게 적용
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            isSvg
                ? SvgPicture.asset(iconAsset, width: 18, height: 18)
                : Image.asset(iconAsset, width: 18, height: 18),
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 8, // 🎯 알림 점 크기도 살짝 축소
                height: 8,
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
      const TravelListPage(),
      const RecordTabPage(),
      const MyPage(),
      const ShopPage(),
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
          height:
              MediaQuery.of(context).padding.bottom +
              59, // ✅ 핵심: 좌우 패딩을 추가하여 메뉴 아이템들을 중앙으로 모음
          padding: const EdgeInsets.symmetric(horizontal: 8),
          // ✅Decoration을 활용해 인덱스에 따라 상단 라인 유무 결정
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border(
              top: BorderSide(
                // 🎯 인덱스가 0(Home)이 아닐 때만 1px 회색 라인 추가
                color: _currentIndex == 0
                    ? Colors.transparent
                    : const Color.fromARGB(255, 243, 243, 243), // 또는 적절한 회색 정의값
                width: 1.0,
              ),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabSelected,
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.background,
            elevation: 0,

            // ✅ 폰트 크기 통일
            selectedFontSize: 11,
            unselectedFontSize: 11,

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
                iconAsset: 'assets/icons/nav_home.svg',
                label: 'nav_home'.tr(),
              ),
              _buildMenuItem(
                iconAsset: 'assets/icons/nav_travel.svg',
                label: 'nav_travel'.tr(),
              ),
              _buildMenuItem(
                iconAsset: 'assets/icons/nav_record.svg',
                label: 'nav_record'.tr(),
              ),
              _buildMenuItem(
                iconAsset: 'assets/icons/nav_my.svg',
                label: 'nav_my'.tr(),
              ),
              _buildMenuItem(
                iconAsset: 'assets/icons/nav_shop.svg',
                label: 'nav_shop'.tr(), // ⭐ 코인/상점
              ),
            ],
          ),
        ),
      ),
    );
  }
}
