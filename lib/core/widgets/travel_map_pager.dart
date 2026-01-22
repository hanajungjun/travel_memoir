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
  late final PageController _controller;

  // 지도를 새로 만들지 않고 제어하기 위한 Key
  final GlobalKey<GlobalMapPageState> _globalMapKey =
      GlobalKey<GlobalMapPageState>();
  final GlobalKey<DomesticMapPageState> _domesticMapKey =
      GlobalKey<DomesticMapPageState>();

  int _index = 0;
  List<String> _activeMapIds = ['world', 'ko'];
  bool _loading = true;
  bool _disposed = false;
  bool _isFirstLoad = true; // 첫 로드 여부 플래그

  @override
  void initState() {
    super.initState();
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

      final next = List<String>.from(res?['active_maps'] ?? ['world', 'ko']);

      _safeSetState(() {
        _activeMapIds = next;
        _loading = false;
      });

      // 처음 로드일 때만 travelType 기준으로 탭 맞추기
      if (_isFirstLoad) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_disposed || !mounted) return;
          _applyInitialIndex();
          _isFirstLoad = false;
        });
      }
    } catch (e) {
      if (_disposed || !mounted) return;
      _safeSetState(() => _loading = false);
    }
  }

  void _applyInitialIndex() {
    final order = <String>[];
    if (_activeMapIds.contains('world')) order.add('world');
    if (_activeMapIds.contains('ko')) order.add('ko');

    final desiredId = widget.travelType == 'domestic' ? 'ko' : 'world';
    final targetIndex = order.indexOf(desiredId);
    final resolvedIndex = targetIndex == -1 ? 0 : targetIndex;

    if (_index != resolvedIndex) {
      _safeSetState(() => _index = resolvedIndex);
      try {
        if (_controller.hasClients) _controller.jumpToPage(resolvedIndex);
      } catch (_) {}
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
    // 상세페이지 복귀 후 호출: 인덱스는 유지하고 데이터만 갱신
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

    final List<Map<String, dynamic>> dynamicConfigs = [];
    if (_activeMapIds.contains('world')) {
      dynamicConfigs.add({
        'id': 'world',
        'label': 'overseas'.tr(),
        'activeColor': AppColors.travelingPurple,
        'page': GlobalMapPage(key: _globalMapKey, showLastTravelFocus: true),
      });
    }
    if (_activeMapIds.contains('ko')) {
      dynamicConfigs.add({
        'id': 'ko',
        'label': 'domestic'.tr(),
        'activeColor': AppColors.travelingBlue,
        'page': DomesticMapPage(key: _domesticMapKey),
      });
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
                  physics: const NeverScrollableScrollPhysics(), // 탭으로만 이동 권장
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
                              travelType: widget.travelType,
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
