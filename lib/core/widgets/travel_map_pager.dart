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
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.tabBackground,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              _Tab(
                label: 'overseas'.tr(), // 해외가 0번(왼쪽)
                selected: _index == 0,
                onTap: () => _move(0),
              ),
              _Tab(
                label: 'domestic'.tr(), // 국내가 1번(오른쪽)
                selected: _index == 1,
                onTap: () => _move(1),
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

                        if (mounted) {
                          _refreshMap();
                        }
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
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            // 선택됐을 때 색상을 AppColors.primary로 적용
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(28), // 둥글게 깎기
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.button.copyWith(
                color: selected ? AppColors.onPrimary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
