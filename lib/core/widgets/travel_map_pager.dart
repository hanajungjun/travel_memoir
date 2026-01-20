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

  // 활성 맵 리스트 (world / ko / us 등)
  List<String> _activeMapIds = ['world', 'ko'];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadActiveMaps();
  }

  /// 🔑 active_maps 로드
  Future<void> _loadActiveMaps() async {
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('active_maps')
          .eq('auth_uid', _userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _activeMapIds = List<String>.from(
            res?['active_maps'] ?? ['world', 'ko'],
          );
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [TravelMapPager] load error: $e');
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
    _loadActiveMaps();
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

    /// 🧭 동적 맵 구성
    final List<Map<String, dynamic>> dynamicConfigs = [];

    if (_activeMapIds.contains('world')) {
      dynamicConfigs.add({
        'label': 'overseas'.tr(),
        'activeColor': AppColors.travelingPurple,
        'page': GlobalMapPage(key: ValueKey('global-map-$_mapKey')),
      });
    }

    if (_activeMapIds.contains('ko')) {
      dynamicConfigs.add({
        'label': 'domestic'.tr(),
        'activeColor': AppColors.travelingBlue,
        'page': DomesticMapPage(key: ValueKey('domestic-map-$_mapKey')),
      });
    }

    if (dynamicConfigs.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('활성화된 지도가 없습니다.')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// ===== 탭 (2개 이상일 때만) =====
        if (dynamicConfigs.length > 1)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Row(
              children: List.generate(dynamicConfigs.length, (i) {
                return _Tab(
                  label: dynamicConfigs[i]['label'],
                  selected: _index == i,
                  onTap: () => _move(i),
                  activeColor: dynamicConfigs[i]['activeColor'],
                  inactiveTextColor: AppColors.textColor05,
                );
              }),
            ),
          ),

        if (dynamicConfigs.length > 1) const SizedBox(height: 12),

        /// ===== 지도 영역 =====
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
                        _refreshMap();
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

/// 🎨 탭 위젯
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
            color: selected ? activeColor : Colors.transparent,
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
