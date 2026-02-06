import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_app_badge_control/flutter_app_badge_control.dart';
import 'package:travel_memoir/app/route_observer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_memoir/services/travel_list_service.dart';
import 'package:travel_memoir/services/stamp_service.dart';

import 'package:travel_memoir/core/widgets/recent_travel_section.dart';
import 'package:travel_memoir/core/widgets/travel_map_pager.dart';
import 'package:travel_memoir/core/widgets/home_travel_status_header.dart';

import 'package:travel_memoir/core/widgets/skeletons/travel_map_skeleton.dart';
import 'package:travel_memoir/core/widgets/skeletons/recent_travel_section_skeleton.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
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

  // ==========================================
  // 🎁 데일리 보상 체크 및 지급
  // ==========================================
  // Future<void> _checkDailyReward() async {
  //   final user = Supabase.instance.client.auth.currentUser;
  //   if (user == null) return;

  //   try {
  //     await FlutterAppBadgeControl.removeBadge();
  //   } catch (e) {
  //     debugPrint("❌ [Badge] 뱃지 제거 실패: $e");
  //   }

  //   final reward = await _stampService.checkAndGrantDailyReward(user.id);

  //   if (reward != null && mounted) {
  //     // ✅ [로그] 보상 수량 확인 (Daily, VIP, Paid)
  //     debugPrint("🎁 [Reward Log] Data: $reward");
  //     _showRewardPopup(reward);
  //   }
  // }
  // ==========================================
  // 🎁 데일리 보상 체크 및 지급
  // ==========================================
  Future<void> _checkDailyReward() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await FlutterAppBadgeControl.removeBadge();
    } catch (e) {
      debugPrint("❌ [Badge] 뱃지 제거 실패: $e");
    }

    // 1️⃣ [로컬 체크] 이 기기에서 오늘 팝업을 이미 봤는지 확인
    final prefs = await SharedPreferences.getInstance();
    final String today = DateTime.now().toString().split(' ')[0]; // yyyy-MM-dd
    final String storageKey = 'last_reward_popup_${user.id}'; // 유저별 고유 키

    if (prefs.getString(storageKey) == today) {
      debugPrint("✅ [Reward] 오늘 이미 팝업을 본 유저(ID: ${user.id})입니다.");
      return; // 팝업을 이미 봤다면 여기서 종료 (서버 요청도 안 함)
    }

    // 2️⃣ 서버에서 보상 데이터 가져오기
    final reward = await _stampService.checkAndGrantDailyReward(user.id);

    if (reward != null && mounted) {
      debugPrint("🎁 [Reward Log] Data: $reward");

      // 3️⃣ 팝업 표시
      _showRewardPopup(reward);

      // 4️⃣ [로컬 저장] 팝업을 보여줬음을 기기에 기록
      await prefs.setString(storageKey, today);
    }
  }

  // ==========================================
  // 🎯 보상 알림 팝업 (reward_config 데이터 활용)
  // ==========================================
  void _showRewardPopup(Map<String, dynamic> reward) {
    final locale = context.locale.languageCode;
    final bool isVip = reward['is_vip'] ?? false; // StampService에서 넘겨준 VIP 여부

    // 1. 제목: 로컬 언어 설정에 맞춰 가져옴 (없으면 한국어 -> 기본값)
    final title = reward['title_$locale'] ?? reward['title_ko'] ?? 'Reward';

    // 2. 설명: DB의 description_ko에 담긴 "일반 5개 + VIP 50개..." 문구 활용
    String desc =
        reward['description_$locale'] ?? reward['description_ko'] ?? '';

    // 3. 텍스트 가공 (줄바꿈 처리 및 {amount} 변수 치환)
    desc = desc.replaceAll(r'\n', '\n');
    if (desc.contains('{amount}')) {
      desc = desc.replaceAll('{amount}', reward['reward_amount'].toString());
    }

    // 4. ✅ [중요] showDynamicIconAlert 호출 (DB 문구 그대로 출력용)
    AppDialogs.showDynamicIconAlert(
      context: context,
      title: title,
      message: desc,
      icon: isVip ? Icons.workspace_premium : Icons.stars, // 🎯 VIP는 전용 아이콘
      iconColor: isVip ? Colors.amber : Colors.orangeAccent,
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
          HomeTravelStatusHeader(onGoToTravel: widget.onGoToTravel),
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
                        final String travelId = travels.isNotEmpty
                            ? travels.first['id']?.toString() ?? 'preview'
                            : 'preview';
                        final String travelType = travels.isNotEmpty
                            ? travels.first['travel_type']?.toString() ??
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
