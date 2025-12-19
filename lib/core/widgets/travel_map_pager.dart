import 'package:flutter/material.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

import 'package:travel_memoir/features/map/pages/domestic_map_page.dart';
import 'package:travel_memoir/features/map/pages/global_map_page.dart';
import 'package:travel_memoir/features/map/pages/map_main_page.dart';

class TravelMapPager extends StatefulWidget {
  const TravelMapPager({super.key});

  @override
  State<TravelMapPager> createState() => _TravelMapPagerState();
}

class _TravelMapPagerState extends State<TravelMapPager> {
  final PageController _controller = PageController();
  int _index = 0;

  void _move(int i) {
    if (_index == i) return;
    setState(() => _index = i);
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ===== 탭 =====
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              _Tab(label: '한국', selected: _index == 0, onTap: () => _move(0)),
              _Tab(label: '해외', selected: _index == 1, onTap: () => _move(1)),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ===== 지도 미리보기 (클릭 시 해당 탭으로 이동) =====
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MapMainPage(initialIndex: _index),
              ),
            );
          },
          child: SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  PageView(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _index = i),
                    children: const [DomesticMapPage(), GlobalMapPage()],
                  ),

                  // 클릭 유도 오버레이
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.35),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Positioned(
                    bottom: 12,
                    right: 12,
                    child: Icon(
                      Icons.open_in_full,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ======================
// 🔹 탭 버튼
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
            borderRadius: BorderRadius.circular(20),
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
