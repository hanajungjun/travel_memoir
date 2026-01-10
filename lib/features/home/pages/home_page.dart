import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // 추가
import 'package:travel_memoir/app/route_observer.dart';

import 'package:travel_memoir/services/travel_service.dart';
import 'package:travel_memoir/services/travel_day_service.dart';
import 'package:travel_memoir/services/travel_list_service.dart';

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

  void _triggerRefresh() {
    if (!mounted) return;
    setState(() {
      _refreshKey++;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    debugPrint("🏠 홈 화면 복귀: 데이터 새로고침 실행");
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
                        "home_cat_message".tr(), // ✅ 번역 적용
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

  static Future<Map<String, dynamic>?> _getTodayDiaryStatus() async {
    final travel = await TravelService.getTodayTravel();
    if (travel == null) return null;
    return await TravelDayService.getDiaryByDate(
      travelId: travel['id'],
      date: DateTime.now(),
    );
  }
}
