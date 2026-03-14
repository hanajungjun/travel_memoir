import 'dart:io';
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
import 'package:travel_memoir/features/travel_list/pages/travel_list_page.dart';
import 'package:travel_memoir/core/widgets/skeletons/travel_map_skeleton.dart';
import 'package:travel_memoir/core/widgets/skeletons/recent_travel_section_skeleton.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/core/widgets/popup/app_dialogs.dart';

/**
 * 📱 Screen ID : HOME_PAGE
 * 📝 Name      : 메인 홈 화면
 * 🛠 Feature   : 보상 팝업, 최근 여행, 지도 페이저
 * 🔄 Refresh   : RouteObserver 실시간 데이터 갱신
 * * [ UI Structure ]
 * ----------------------------------------------------------
 * home_page.dart (Scaffold)
 * ├── home_travel_status_header.dart  [상단 헤더]
 * ├── recent_travel_section.dart      [최근 여행 섹션]
 * │    └── recent_travel_section_skeleton.dart (로딩)
 * ├── travel_map_pager.dart           [메인 지도 영역]
 * │    └── travel_map_skeleton.dart (로딩)
 * └── app_dialogs.dart                [보상 팝업 - Overlay]
 * ----------------------------------------------------------
 */

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

  // ==========================================
  // 🎁 데일리 보상 체크 및 지급
  // ==========================================
  Future<void> _checkDailyReward() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // ✅ 안드로이드는 badge API 지원 안 함 → iOS만 실행
    if (Platform.isIOS) {
      try {
        await FlutterAppBadgeControl.removeBadge();
      } catch (e) {}
    }

    // 일반 보상 수량
    int normalRewardAmount = 5;
    try {
      final normalData = await Supabase.instance.client
          .from('reward_config')
          .select('reward_amount')
          .eq('type', 'daily_login')
          .maybeSingle();
      if (normalData != null) {
        normalRewardAmount = normalData['reward_amount'] as int;
      }
    } catch (e) {}

    // 신규 가입자 여부
    bool isNewUser = false;
    try {
      final userData = await Supabase.instance.client
          .from('users')
          .select('created_at')
          .eq('auth_uid', user.id)
          .maybeSingle();
      if (userData != null) {
        final createdAt = DateTime.parse(userData['created_at']).toLocal();
        isNewUser = DateTime.now().difference(createdAt).inHours < 24;
      }
    } catch (e) {}

    final reward = await _stampService.checkAndGrantDailyReward(user.id);

    if (reward != null && mounted) {
      final Map<String, dynamic> rewardWithNormal = Map.from(reward);
      rewardWithNormal['normal_amount'] = normalRewardAmount;
      rewardWithNormal['is_new_user'] = isNewUser;
      _showRewardPopup(rewardWithNormal);
    }
  }

  // ==========================================
  // 🎯 보상 알림 팝업 (전달받은 normal_amount 활용)
  // ==========================================
  void _showRewardPopup(Map<String, dynamic> reward) {
    final locale = context.locale.languageCode;
    final bool isVip = reward['is_vip'] ?? false;
    final bool isNewUser = reward['is_new_user'] ?? false; // 👈 추가

    final title = reward['title_$locale'] ?? reward['title_ko'] ?? 'Reward';
    String desc =
        reward['description_$locale'] ?? reward['description_ko'] ?? '';
    desc = desc.replaceAll(r'\n', '\n');

    // 🎯 신규 가입자면 메시지 덮어쓰기
    if (isNewUser) {
      desc = 'welcome_message'.tr();
    } else {
      final String normalAmount = (reward['normal_amount'] ?? "5").toString();
      final String vipAmount = (reward['reward_amount'] ?? "0").toString();
      if (desc.contains('{amount}'))
        desc = desc.replaceAll('{amount}', normalAmount);
      if (desc.contains('{reward_amount}'))
        desc = desc.replaceAll('{reward_amount}', vipAmount);
    }

    AppDialogs.showDynamicIconAlert(
      context: context,
      title: title,
      message: desc,
      icon: isNewUser
          ? Icons.card_giftcard
          : (isVip ? Icons.workspace_premium : Icons.stars),
      iconColor: isNewUser
          ? AppColors.travelingPurple
          : (isVip ? Colors.amber : Colors.orangeAccent),
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
          HomeTravelStatusHeader(
            // key: ValueKey('header-$_refreshKey'), // 이건 이미 잘 넣으셨습니다!
            onGoToTravel: () async {
              // 🎯 [수정] 이동할 때 await를 붙이고, 돌아오면 새로고침 함수를 호출합니다.
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TravelListPage()),
              );
              _triggerRefresh(); // 리스트 보고 돌아오면 무조건 홈 화면 갱신!
            },
            onRefresh: _triggerRefresh,
          ),
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
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      key: ValueKey('map-$_refreshKey'),
                      future: TravelListService.getTravels(),
                      builder: (context, snapshot) {
                        final travels = snapshot.data ?? [];
                        // 🎯 [수정 핵심] 오늘 날짜를 포함하는 여행이 있는지 먼저 찾습니다.
                        final now = DateTime.now();
                        final today =
                            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

                        // 리스트 중 오늘 날짜(start_date <= today <= end_date)에 걸리는 여행 찾기
                        final currentTravel = travels.firstWhere(
                          (t) =>
                              (t['start_date'] ?? "").toString().compareTo(
                                    today,
                                  ) <=
                                  0 &&
                              (t['end_date'] ?? "").toString().compareTo(
                                    today,
                                  ) >=
                                  0,
                          orElse: () => travels.isNotEmpty
                              ? travels.first
                              : {}, // 없으면 그냥 첫 번째
                        );

                        final String travelId = currentTravel.isNotEmpty
                            ? currentTravel['id']?.toString() ?? 'preview'
                            : 'preview';

                        final String travelType = currentTravel.isNotEmpty
                            ? currentTravel['travel_type']?.toString() ??
                                  'overseas'
                            : 'overseas';

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
