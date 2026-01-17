import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart'; // ✅ 배지 제거를 위해 추가
import 'package:travel_memoir/app/route_observer.dart';

import 'package:travel_memoir/services/travel_list_service.dart';
import 'package:travel_memoir/services/stamp_service.dart';

import 'package:travel_memoir/core/widgets/recent_travel_section.dart';
import 'package:travel_memoir/core/widgets/travel_map_pager.dart';
import 'package:travel_memoir/core/widgets/home_travel_status_header.dart';

import 'package:travel_memoir/core/widgets/skeletons/travel_map_skeleton.dart';
import 'package:travel_memoir/core/widgets/skeletons/recent_travel_section_skeleton.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onGoToTravel;
  const HomePage({super.key, required this.onGoToTravel});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  int _refreshKey = 0;
  final StampService _stampService = StampService();

  @override
  void initState() {
    super.initState();
    // 1초 뒤 안전하게 보상 체크 실행
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 1000));
      _checkDailyReward();
    });
  }

  Future<void> _checkDailyReward() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // ✅ 앱 실행 시 배지 숫자 '1'을 지웁니다.
    bool isSupported = await FlutterAppBadger.isAppBadgeSupported();
    if (isSupported) {
      FlutterAppBadger.removeBadge();
    }

    print("🚀 [HomePage] 보상 체크 프로세스 시작...");
    bool isGranted = await _stampService.checkAndGrantDailyReward(user.id);
    print("🚀 [HomePage] 지급 여부: $isGranted");

    if (isGranted && mounted) {
      _showRewardPopup();
    }
  }

  void _showRewardPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Center(
          child: Text(
            "🎁 오늘의 선물",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.stars, size: 60, color: Colors.orangeAccent),
            SizedBox(height: 20),
            Text(
              "새로운 날이 밝았습니다!\n데일리 코인 5개가 추가되었습니다.",
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                _triggerRefresh();
              },
              child: const Text(
                "닫기",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _triggerRefresh() {
    if (mounted) setState(() => _refreshKey++);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _triggerRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          HomeTravelStatusHeader(onGoToTravel: widget.onGoToTravel),
          Expanded(
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  bottom: 30,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 100,
                        child: Image.asset(
                          'assets/images/durub.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.pets,
                                size: 50,
                                color: Colors.grey,
                              ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "home_cat_message".tr(),
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Container(
                        color: AppColors.lightBackground,
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FutureBuilder(
                              key: ValueKey('recent-$_refreshKey'),
                              future: TravelListService.getRecentTravels(),
                              builder: (context, snapshot) {
                                return AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  child:
                                      snapshot.connectionState ==
                                          ConnectionState.waiting
                                      ? const RecentTravelSectionSkeleton(
                                          key: ValueKey('recent-skeleton'),
                                        )
                                      : RecentTravelSection(
                                          key: const ValueKey('recent-content'),
                                          onSeeAll: widget.onGoToTravel,
                                        ),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                            FutureBuilder<List<Map<String, dynamic>>>(
                              key: ValueKey('map-$_refreshKey'),
                              future: TravelListService.getTravels(),
                              builder: (context, snapshot) {
                                final travels = snapshot.data ?? [];
                                final String? travelId = travels.isNotEmpty
                                    ? travels.first['id']
                                    : null;
                                return AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  child:
                                      snapshot.connectionState ==
                                          ConnectionState.waiting
                                      ? const TravelMapSkeleton(
                                          key: ValueKey('map-skeleton'),
                                        )
                                      : Container(
                                          key: const ValueKey('map-content'),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppColors.lightSurface,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: SizedBox(
                                            height: 380,
                                            child: TravelMapPager(
                                              travelId: travelId ?? 'preview',
                                            ),
                                          ),
                                        ),
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
