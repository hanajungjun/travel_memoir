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
  final PageController _controller = PageController();
  int _index = 0;
  int _mapKey = 0;

  // ✅ [에러방지] 안전하게 setState를 호출하는 헬퍼 함수
  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _move(int i) {
    if (_index == i) return;

    // 페이지 이동 전 위젯 상태 체크
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
        // ===== 탭 =====
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.tabBackground,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              _Tab(
                label: 'domestic'.tr(),
                selected: _index == 0,
                onTap: () => _move(0),
              ),
              _Tab(
                label: 'overseas'.tr(),
                selected: _index == 1,
                onTap: () => _move(1),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ===== 지도 (부모 높이에 맞춰서 꽉 채움) =====
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                PageView(
                  controller: _controller,
                  // ✅ 페이지 변경 시에도 안전하게 index 업데이트
                  onPageChanged: (i) => _safeSetState(() => _index = i),
                  children: [
                    DomesticMapPage(key: ValueKey('domestic-map-$_mapKey')),
                    // ✅ [에러방지] 해외 지도에도 유니크 키를 부여해 뷰 충돌을 막습니다.
                    GlobalMapPage(key: ValueKey('global-map-$_mapKey')),
                  ],
                ),

                // 전체 지도 이동
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

                        // ✅ [에러방지] 화면에서 돌아왔을 때 위젯이 아직 존재하는지 확인 후 리프레시
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

// ======================
// 탭 버튼 (기존과 동일)
// ======================
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
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.button.copyWith(
                color: selected ? AppColors.onPrimary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
