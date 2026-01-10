import 'package:flutter/material.dart';

// ✅ routeObserver 경로 확인 필수!
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
// ✅ AppTextStyles 클래스 이름 확인
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
          // 🔵 Header: 상단 고정
          HomeTravelStatusHeader(onGoToTravel: widget.onGoToTravel),

          // ⬇️ Content Area
          Expanded(
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // 1️⃣ [배경 고양이]
                // 리스트 바닥보다 살짝 위에 배치해서 당겼을 때 바로 보이게 합니다.
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
                        "새로운 여행을 기록해볼까요? 냥! 🐾",
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                // 2️⃣ [메인 콘텐츠 레이어]
                CustomScrollView(
                  // 💡 쫀득하게 튕기는 손맛의 핵심 설정!
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Container(
                        // 💡 리스트의 배경색. 이 부분이 고양이를 가리는 '커튼'입니다.
                        color: AppColors.lightBackground,
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 🧳 Recent Travel Section (기존 기능 그대로)
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

                            // 🗺️ Travel Map Section (기존 기능 그대로)
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

                            // 💡 바닥에 아주 약간의 여백만 줍니다. (고양이가 너무 일찍 보이지 않게)
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),

                    // 💡 여기에 있던 SizedBox를 없앴습니다!
                    // 리스트가 여기서 끝나야만 당겼을 때 다시 위로 '팅~' 하고 복귀합니다.
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 기존 헬퍼 함수 유지
  static Future<Map<String, dynamic>?> _getTodayDiaryStatus() async {
    final travel = await TravelService.getTodayTravel();
    if (travel == null) return null;
    return await TravelDayService.getDiaryByDate(
      travelId: travel['id'],
      date: DateTime.now(),
    );
  }
}
