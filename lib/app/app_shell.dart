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

  BottomNavigationBarItem _buildMenuItem({
    required String iconAsset,
    required String label,
  }) {
    return BottomNavigationBarItem(
      icon: Padding(
        padding: const EdgeInsets.only(bottom: 2), // ✅ 살짝 줄임
        child: Image.asset(iconAsset, width: 22, height: 22),
      ),
      activeIcon: Padding(
        padding: const EdgeInsets.only(bottom: 2), // ✅ 살짝 줄임
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Image.asset(iconAsset, width: 22, height: 22),
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                width: 10,
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
      body: IndexedStack(index: _currentIndex, children: pages),

      // ✅ 핵심: BottomNavigationBarTheme로 내부 레이아웃까지 안정적으로 잡는다
      bottomNavigationBar: BottomNavigationBarTheme(
        data: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.background,
          selectedItemColor: AppColors.textColor01,
          unselectedItemColor: AppColors.textColor01,

          // ✅ 오버플로우 방지 포인트
          selectedLabelStyle: TextStyle(fontSize: 11, height: 1.0),
          unselectedLabelStyle: TextStyle(fontSize: 11, height: 1.0),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 72, // ✅ 80 -> 72 정도가 안정적 (원하면 76도 OK)
            child: BottomNavigationBar(
              key: ValueKey(context.locale.toString()),
              currentIndex: _currentIndex,
              onTap: _onTabSelected,
              type: BottomNavigationBarType.fixed,

              // ✅ 여기 숫자도 너무 키우면 다시 overflow 날 수 있음
              selectedFontSize: 11,
              unselectedFontSize: 11,

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
