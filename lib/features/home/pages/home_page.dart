import 'package:flutter/material.dart';

// ✅ 만약 routeObserver가 다른 파일에 있다면 해당 경로로 수정해주세요!
import 'package:travel_memoir/app/route_observer.dart';

import 'package:travel_memoir/services/travel_service.dart';
import 'package:travel_memoir/services/travel_day_service.dart';
import 'package:travel_memoir/services/travel_list_service.dart';

import 'package:travel_memoir/features/travel_diary/pages/travel_diary_list_page.dart';

import 'package:travel_memoir/core/utils/date_utils.dart';
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

// ✅ RouteAware를 추가하여 화면 복귀를 감시합니다.
class _HomePageState extends State<HomePage> with RouteAware {
  int _refreshKey = 0;

  // 🔄 화면을 새로고침하는 함수
  void _triggerRefresh() {
    if (!mounted) return;
    setState(() {
      _refreshKey++;
    });
  }

  // ================= Route 감시 설정 =================
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

  // 🔥 다른 페이지(삭제 페이지 등)에 갔다가 다시 홈으로 돌아오면 자동 실행!
  @override
  void didPopNext() {
    debugPrint("🏠 홈 화면 복귀: 데이터 새로고침 실행");
    _triggerRefresh();
  }
  // =================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          // 🔵 Header
          HomeTravelStatusHeader(onGoToTravel: widget.onGoToTravel),

          // ⬇️ Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🧳 Recent Travel
                  FutureBuilder(
                    // ✅ _refreshKey가 바뀔 때마다 FutureBuilder가 다시 실행됩니다.
                    key: ValueKey('recent-$_refreshKey'),
                    future: TravelListService.getRecentTravels(),
                    builder: (context, snapshot) {
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child:
                            snapshot.connectionState == ConnectionState.waiting
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

                  // 🗺️ Travel Map
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
                            snapshot.connectionState == ConnectionState.waiting
                            ? const TravelMapSkeleton(
                                key: ValueKey('map-skeleton'),
                              )
                            : Container(
                                key: const ValueKey('map-content'),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.lightSurface,
                                  borderRadius: BorderRadius.circular(16),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= helpers =================
  static Future<Map<String, dynamic>?> _getTodayDiaryStatus() async {
    final travel = await TravelService.getTodayTravel();
    if (travel == null) return null;

    return await TravelDayService.getDiaryByDate(
      travelId: travel['id'],
      date: DateTime.now(),
    );
  }
}
