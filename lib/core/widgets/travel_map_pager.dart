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
  final String travelType;

  const TravelMapPager({
    super.key,
    required this.travelId,
    required this.travelType,
  });

  @override
  State<TravelMapPager> createState() => _TravelMapPagerState();
}

class _TravelMapPagerState extends State<TravelMapPager> {
  final String _userId = Supabase.instance.client.auth.currentUser!.id;
  late PageController _controller;

  final GlobalKey<GlobalMapPageState> _globalMapKey =
      GlobalKey<GlobalMapPageState>();
  final GlobalKey<DomesticMapPageState> _domesticMapKey =
      GlobalKey<DomesticMapPageState>();

  int _index = 0;
  List<String> _activeMapIds = ['world', 'ko'];
  bool _loading = true;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    // 초기에는 0으로 세팅 (나중에 _loadActiveMaps에서 해외 지도로 보정)
    _controller = PageController(initialPage: 0);
    _loadActiveMaps();
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (_disposed || !mounted) return;
    setState(fn);
  }

  Future<void> _loadActiveMaps() async {
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('active_maps')
          .eq('auth_uid', _userId)
          .maybeSingle();

      if (_disposed || !mounted) return;

      // 💡 [해외 지도 우선순위 로직]
      // DB에서 가져온 리스트에서 'world'를 무조건 맨 앞으로 보냅니다.
      List<String> next = List<String>.from(
        res?['active_maps'] ?? ['world', 'ko'],
      );

      if (next.contains('world')) {
        next.remove('world');
        next.insert(0, 'world'); // 무조건 0번 인덱스는 'world'
      }

      // 💡 [인덱스 강제 고정]
      // 사용자가 요청한 대로 첫 인덱스는 무조건 'world'(해외 지도)가 되도록 0으로 설정합니다.
      int targetIdx = 0;

      _safeSetState(() {
        _activeMapIds = next;
        _index = targetIdx;
        _loading = false;

        // 기존 컨트롤러를 버리고 해외 지도가 0번인 새 컨트롤러로 교체
        _controller.dispose();
        _controller = PageController(initialPage: _index);
      });
    } catch (e) {
      if (_disposed || !mounted) return;
      _safeSetState(() => _loading = false);
    }
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

  Future<void> _refreshMap() async {
    await _loadActiveMaps();
    _globalMapKey.currentState?.refreshData();
    _domesticMapKey.currentState?.refreshData();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );

    // 💡 현재 맵 ID 순서에 따라 페이지 구성
    final List<Map<String, dynamic>> dynamicConfigs = [];
    for (var id in _activeMapIds) {
      if (id == 'world') {
        dynamicConfigs.add({
          'id': 'world',
          'type': 'overseas',
          'label': 'overseas'.tr(),
          'activeColor': AppColors.travelingPurple,
          'page': GlobalMapPage(key: _globalMapKey, showLastTravelFocus: true),
        });
      } else if (id == 'ko') {
        dynamicConfigs.add({
          'id': 'ko',
          'type': 'domestic',
          'label': 'domestic'.tr(),
          'activeColor': AppColors.travelingBlue,
          'page': DomesticMapPage(key: _domesticMapKey),
        });
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                PageView(
                  controller: _controller,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => _safeSetState(() => _index = i),
                  children: dynamicConfigs
                      .map((c) => c['page'] as Widget)
                      .toList(),
                ),
                // 💡 지도를 탭했을 때 현재 인덱스의 타입에 맞는 메인 페이지로 이동
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        final currentType = dynamicConfigs[_index]['type'];

                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MapMainPage(
                              travelId: widget.travelId,
                              travelType: currentType,
                            ),
                          ),
                        );
                        await _refreshMap();
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

// 💡 탭 위젯 (버튼)
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
