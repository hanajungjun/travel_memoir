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
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/core/widgets/popup/app_dialogs.dart';

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

    final reward = await _stampService.checkAndGrantDailyReward(user.id);

    // ✅ [VIP 전용 로그 추가] 보상 확인 시점에 VIP 스탬프 수량 로그 출력
    if (reward != null) {
      debugPrint(
        "🎁 [Stamp Reward Log] Daily: ${reward['daily_stamps']}, VIP: ${reward['vip_stamps']}, Paid: ${reward['paid_stamps']}",
      );
    }

    if (reward != null && mounted) {
      _showRewardPopup(reward);
    }
  }

  void _showRewardPopup(Map<String, dynamic> reward) {
    final locale = context.locale.languageCode;

    final title = reward['title_$locale'] ?? reward['title_ko'] ?? '🎁 Reward';

    final descTemplate =
        reward['description_$locale'] ?? reward['description_ko'] ?? '';

    final desc = descTemplate
        .replaceAll(r'\n', '\n')
        .replaceAll('{amount}', reward['reward_amount'].toString());

    AppDialogs.showIconAlert(
      context: context,
      title: title,
      message: desc,
      icon: Icons.stars,
      iconColor: Colors.orangeAccent,
      barrierDismissible: false,
      onClose: () => _triggerRefresh(),
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
          // 1. 상단 헤더
          HomeTravelStatusHeader(onGoToTravel: widget.onGoToTravel),

          // 2. 메인 컨텐츠
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                27,
                20,
                27,
                MediaQuery.of(context).padding.bottom + 5,
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 최근 여행
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

                  const SizedBox(height: 20),

                  // ✅ 지도 섹션 (travelType을 실제 데이터에서 추출)
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      key: ValueKey('map-$_refreshKey'),
                      future: TravelListService.getTravels(),
                      builder: (context, snapshot) {
                        final travels = snapshot.data ?? [];

                        final String travelId = travels.isNotEmpty
                            ? travels.first['id']?.toString() ?? 'preview'
                            : 'preview';

                        final String travelType = travels.isNotEmpty
                            ? travels.first['travel_type']?.toString() ??
                                  'overseas'
                            : 'overseas';

                        debugPrint(
                          '🧭 [HomePage] travelId=$travelId travelType=$travelType',
                        );

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
                                  child: TravelMapPager(
                                    travelId: travelId,
                                    travelType: travelType,
                                  ),
                                ),
                        );
                      },
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
