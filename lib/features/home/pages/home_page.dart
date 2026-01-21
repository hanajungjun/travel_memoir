import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_app_badge_control/flutter_app_badge_control.dart';
import 'package:travel_memoir/app/route_observer.dart';

import 'package:travel_memoir/services/travel_list_service.dart';
import 'package:travel_memoir/services/stamp_service.dart';

import 'package:travel_memoir/core/widgets/recent_travel_section.dart';
import 'package:travel_memoir/core/widgets/travel_map_pager.dart';
import 'package:travel_memoir/core/widgets/home_travel_status_header.dart';

import 'package:travel_memoir/core/widgets/skeletons/travel_map_skeleton.dart';
import 'package:travel_memoir/core/widgets/skeletons/recent_travel_section_skeleton.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 1000));
      _checkDailyReward();
    });
  }

  Future<void> _checkDailyReward() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await FlutterAppBadgeControl.removeBadge();
    } catch (e) {
      debugPrint("❌ [Badge] 뱃지 제거 실패: $e");
    }

    bool isGranted = await _stampService.checkAndGrantDailyReward(user.id);
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
  void didPopNext() => _triggerRefresh();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // 1. 상단 고정 헤더
          HomeTravelStatusHeader(onGoToTravel: widget.onGoToTravel),

          // 2. 메인 컨텐츠 영역
          Expanded(
            child: Padding(
<<<<<<< HEAD
              // 🎯 [수정] 상단 여백을 15에서 0으로 줄여서 간격을 좁혔습니다.
              padding: const EdgeInsets.fromLTRB(25, 10, 25, 0),
=======
              padding: const EdgeInsets.fromLTRB(27, 15, 27, 82),
>>>>>>> dda4149 (디자인수정)
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 최근 여행 섹션
                  FutureBuilder(
                    key: ValueKey('recent-$_refreshKey'),
                    future: TravelListService.getRecentTravels(),
                    builder: (context, snapshot) {
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child:
                            snapshot.connectionState == ConnectionState.waiting
                            ? const RecentTravelSectionSkeleton()
                            : RecentTravelSection(
                                onSeeAll: widget.onGoToTravel,
                              ),
                      );
                    },
                  ),

<<<<<<< HEAD
                  // 섹션 간 간격 (너무 넓으면 10 정도로 줄여보세요)
                  const SizedBox(height: 15),

                  // 여행 지도 섹션
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FutureBuilder<List<Map<String, dynamic>>>(
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
                                ? const TravelMapSkeleton()
                                : Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(13),
                                    decoration: BoxDecoration(
                                      color: AppColors.lightSurface,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: TravelMapPager(
                                      travelId: travelId ?? 'preview',
                                    ),
=======
                  const SizedBox(height: 20),

                  // ✅ [핵심] 지도 섹션은 남은 공간 전부 차지하게 Expanded로 감싼다
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
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
                              ? const TravelMapSkeleton()
                              : Container(
                                  padding: const EdgeInsets.all(13),
                                  decoration: BoxDecoration(
                                    color: AppColors.lightSurface,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  // ✅ 기존: height 0.45 고정 (여백 원인)
                                  // ✅ 변경: 남은 공간을 그대로 채우게 그냥 넣는다
                                  child: TravelMapPager(
                                    travelId: travelId ?? 'preview',
>>>>>>> dda4149 (디자인수정)
                                  ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
