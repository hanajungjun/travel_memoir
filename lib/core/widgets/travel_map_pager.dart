import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final String _userId = Supabase.instance.client.auth.currentUser!.id;
  final PageController _controller = PageController(initialPage: 0);

  int _index = 0;
  int _mapKey = 0;

  // ✅ 활성 맵 관리를 위한 변수
  List<String> _activeMapIds = ['world', 'ko'];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadActiveMaps();
  }

  /// ✅ Supabase에서 활성화된 맵 리스트 가져오기
  Future<void> _loadActiveMaps() async {
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('active_maps')
          .eq('auth_uid', _userId)
          .maybeSingle();

      if (res != null && res['active_maps'] != null) {
        if (mounted) {
          setState(() {
            _activeMapIds = List<String>.from(res['active_maps']);
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('❌ [TravelMapPager] Load Error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

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
    _loadActiveMaps(); // ✅ 맵 설정 변경 가능성이 있으므로 다시 로드
    _safeSetState(() => _mapKey++);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // 🎯 동적 탭 구성 로직
    final List<Map<String, dynamic>> dynamicConfigs = [];
    if (_activeMapIds.contains('world')) {
      dynamicConfigs.add({
        'label': 'overseas'.tr(),
        'page': GlobalMapPage(key: ValueKey('global-map-$_mapKey')),
      });
    }
    if (_activeMapIds.contains('ko')) {
      dynamicConfigs.add({
        'label': 'domestic'.tr(),
        'page': DomesticMapPage(key: ValueKey('domestic-map-$_mapKey')),
      });
    }

    // 활성화된 지도가 없을 경우 예외 처리
    if (dynamicConfigs.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text("활성화된 지도가 없습니다.")),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ===== 탭: 활성 맵이 2개 이상일 때만 표시 =====
        if (dynamicConfigs.length > 1)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Row(
              children: List.generate(dynamicConfigs.length, (index) {
                return _Tab(
                  label: dynamicConfigs[index]['label'],
                  selected: _index == index,
                  onTap: () => _move(index),
                );
              }),
            ),
          ),
<<<<<<< Updated upstream
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
=======

        if (dynamicConfigs.length > 1) const SizedBox(height: 12),
>>>>>>> Stashed changes

        // ===== 지도 영역 =====
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                PageView(
                  controller: _controller,
                  onPageChanged: (i) => _safeSetState(() => _index = i),
                  children: dynamicConfigs
                      .map((c) => c['page'] as Widget)
                      .toList(),
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
<<<<<<< Updated upstream

                        if (mounted) _refreshMap();
=======
                        _refreshMap(); // 설정 변경 후 돌아왔을 때 갱신
>>>>>>> Stashed changes
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

// 🎨 커스텀 탭 위젯 (이 부분이 빠져서 에러가 났었습니다)
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
<<<<<<< Updated upstream
            color: selected ? activeColor : AppColors.onPrimary,
=======
            color: selected ? AppColors.primary : Colors.transparent,
>>>>>>> Stashed changes
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
