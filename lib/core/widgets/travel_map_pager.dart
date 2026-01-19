import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

import 'package:travel_memoir/features/map/pages/domestic_map_page.dart';
import 'package:travel_memoir/features/map/pages/global_map_page.dart';
import 'package:travel_memoir/features/map/pages/map_main_page.dart';

class TravelMapPager extends StatefulWidget {
  final String travelId;

  const TravelMapPager({super.key, required this.travelId});

  @override
  State<TravelMapPager> createState() => _TravelMapPagerState();
}

class _TravelMapPagerState extends State<TravelMapPager> {
  // ✅ 해외지도가 0번이므로 초기 인덱스 0
  final PageController _controller = PageController(initialPage: 0);
  int _index = 0;
  int _mapKey = 0;

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _move(int i) {
    if (_index == i) return;
    _safeSetState(() => _index = i);
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _refreshMap() {
    _safeSetState(() => _mapKey++);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ===== 탭 (해외 왼쪽 배치) =====
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(40),
          ),
          child: Row(
            children: [
              _Tab(
                label: 'overseas'.tr(), // 해외가 0번(왼쪽)
                selected: _index == 0,
                onTap: () => _move(0),
                activeColor: AppColors.travelingPurple, // 🌍 해외
                inactiveTextColor: AppColors.textColor05,
              ),
              _Tab(
                label: 'domestic'.tr(), // 국내가 1번(오른쪽)
                selected: _index == 1,
                onTap: () => _move(1),
                activeColor: AppColors.travelingBlue, // 🇰🇷 국내
                inactiveTextColor: AppColors.textColor05,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ===== 지도 영역 =====
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                PageView(
                  controller: _controller,
                  onPageChanged: (i) => _safeSetState(() => _index = i),
                  children: [
                    // ✅ 인덱스 0: 해외 지도
                    GlobalMapPage(key: ValueKey('global-map-$_mapKey')),
                    // ✅ 인덱스 1: 국내 지도
                    DomesticMapPage(key: ValueKey('domestic-map-$_mapKey')),
                  ],
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MapMainPage(
                              travelId: widget.travelId,
                              initialIndex: _index,
                            ),
                          ),
                        );

                        if (mounted) _refreshMap();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color activeColor;
  final Color inactiveTextColor;

  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.activeColor,
    required this.inactiveTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? activeColor : AppColors.onPrimary,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.button.copyWith(
                color: selected ? AppColors.onPrimary : inactiveTextColor,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
