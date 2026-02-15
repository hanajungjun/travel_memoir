import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lottie/lottie.dart';

import 'package:travel_memoir/services/payment_service.dart';
import 'package:travel_memoir/app/route_observer.dart';

import 'package:travel_memoir/features/my/pages/profile_edit_page.dart';
import 'package:travel_memoir/features/my/pages/my_travels/my_travel_summary_page.dart';
import 'package:travel_memoir/features/my/pages/settings/my_settings_page.dart';
import 'package:travel_memoir/features/my/pages/supports/my_support_page.dart';
import 'package:travel_memoir/features/my/pages/user_details/user_details.dart';
import 'package:travel_memoir/features/shop/page/shop_page.dart';
import 'package:travel_memoir/features/my/pages/sticker/passport_open_dialog.dart';
import 'package:travel_memoir/features/my/pages/map_management/map_management_page.dart';

import 'package:travel_memoir/core/utils/travel_utils.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/core/widgets/popup/app_dialogs.dart';

/**
 * 📱 Screen ID : MY_PAGE
 * 📝 Name      : 마이페이지 (프로필 및 설정 허브)
 * 🛠 Feature   : 
 * - 사용자 프로필 정보 및 여행 통계 조회
 * - 등급별(VIP, Premium) 배지 노출 및 프리미엄 전용 여권 스티커 기능
 * - 결제 성공 시 PaymentService 알림을 통한 실시간 데이터 새로고침
 * - 하단 그리드 메뉴를 통한 설정, 지도 관리, 지원 페이지 이동
 * * [ UI Structure ]
 * ----------------------------------------------------------
 * my_page.dart (Scaffold)
 * ├── SingleChildScrollView (Body)
 * │    ├── ProfileSection [닉네임, 등급 배지, 프로필 이미지]
 * │    ├── PassportBanner [여권 스티커 팝업 진입 - 프리미엄 전용]
 * │    ├── Tile 1: [나의 여행] -> 완료된 여행 통계 및 요약
 * │    │           (path: lib/features/my/pages/my_travels/my_travel_summary_page.dart)
 * │    ├── Tile 2: [지도 설정] -> 보유 지도 활성화/비활성화 관리
 * │    │           (path: lib/features/my/pages/map_management/map_management_page.dart)
 * │    ├── Tile 3: [계정 관리] -> 계정 정보 확인 및 회원 탈퇴/로그아웃
 * │    │           (path: lib/features/my/pages/user_details/user_details.dart)
 * │    ├── Tile 4: [고객 지원] -> 이용약관 및 고객 센터 연결
 * │    │           (path: lib/features/my/pages/supports/my_support_page.dart)
 * │    ├── Tile 5: [설정]      -> 알림 설정 및 다국어/버전 관리
 * │    │           (path: lib/features/my/pages/settings/my_settings_page.dart)
 * └── passport_open_dialog.dart [여권 스티커 연출 팝업]
 * ----------------------------------------------------------
 */
class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> with RouteAware {
  late Future<Map<String, dynamic>> _profileDataFuture;

  @override
  void initState() {
    super.initState();
    _profileDataFuture = _getProfileData();

    // 🎯 [핵심] 방송국 신호 감청 시작!
    // PaymentService에서 신호를 쏘면 즉시 _onPaymentRefresh가 실행됩니다.
    PaymentService.refreshNotifier.addListener(_onPaymentRefresh);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // RouteObserver 구독 (안전장치 유지)
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    // 🎯 수신기 제거 (메모리 누수 방지)
    PaymentService.refreshNotifier.removeListener(_onPaymentRefresh);
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // ✨ 결제 성공 신호를 받았을 때 실행될 콜백
  void _onPaymentRefresh() {
    debugPrint("📡 [MyPage] 방송 수신: 결제 성공이 확인되어 데이터를 새로고침합니다.");
    _refreshPage();
  }

  @override
  void didPopNext() {
    debugPrint("🔄 [MyPage] 복귀 감지: 데이터 새로고침 실행");
    // 페이지로 돌아왔을 때 한 번 더 확실하게 갱신
    Future.delayed(const Duration(milliseconds: 300), () {
      _refreshPage();
    });
  }

  void _refreshPage() {
    if (!mounted) return;
    setState(() {
      _profileDataFuture = _getProfileData();
    });
  }

  // 1. 하드코딩된 테스트 팝업 메서드
  void _showTestRewardPopup() {
    // 🎯 디자인 수정을 위해 여기에 직접 문구와 수치를 넣으세요.
    const String testTitle = "데일리 보상 도착!"; // title_ko 역할
    const String testNormalAmount = "5";
    const String testVipAmount = "10";

    // 홈 화면의 desc 치환 로직을 미리 적용한 문구
    String testDesc =
        "오늘의 접속 보상으로 스탬프 $testNormalAmount개가 지급되었습니다.\nVIP 멤버십 혜택으로 $testVipAmount개가 추가되었습니다!";

    AppDialogs.showDynamicIconAlert(
      context: context,
      title: testTitle,
      message: testDesc,
      icon: Icons.workspace_premium, // VIP 아이콘 테스트용
      iconColor: Colors.amber, // 금색 테스트
      barrierDismissible: true, // 닫기 편하게 설정
      onClose: () {
        debugPrint("팝업 닫힘");
      },
    );
  }

  Future<Map<String, dynamic>> _getProfileData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        return {'profile': null, 'completedTravels': [], 'travelCount': 0};
      }

      final userId = user.id;
      final userFuture = Supabase.instance.client
          .from('users')
          .select()
          .eq('auth_uid', userId)
          .maybeSingle();
      final travelFuture = Supabase.instance.client
          .from('travels')
          .select('*')
          .eq('user_id', userId)
          .eq('is_completed', true)
          .order('created_at', ascending: false);

      final results = await Future.wait([userFuture, travelFuture]);
      return {
        'profile': results[0],
        'completedTravels': results[1] ?? [],
        'travelCount': (results[1] as List?)?.length ?? 0,
      };
    } catch (e) {
      rethrow;
    }
  }

  void _handlePassportTap(bool hasAccess) {
    if (hasAccess) {
      _showStickerPopup(context);
    } else {
      AppDialogs.showAction(
        context: context,
        title: 'premium_only_title',
        message: 'premium_benefit_desc',
        actionLabel: 'go_to_shop',
        actionColor: Colors.amber,
        onAction: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ShopPage()),
          );
          _refreshPage();
        },
      );
    }
  }

  void _showStickerPopup(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'PassportPopup',
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => const PassportOpeningDialog(),
      transitionBuilder: (context, anim1, anim2, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _profileDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 40,
                    ),
                    const SizedBox(height: 10),
                    Text("데이터를 불러오지 못했습니다.\n${snapshot.error}"),
                    TextButton(
                      onPressed: _refreshPage,
                      child: const Text("다시 시도"),
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!['profile'] == null) {
              return Center(child: Text("error_loading_data".tr()));
            }

            final profile = snapshot.data!['profile'];
            final travelCount = snapshot.data!['travelCount'] as int;
            final nickname = profile['nickname'] ?? 'default_nickname'.tr();
            final imageUrl = profile['profile_image_url'];
            final badge = getBadge(travelCount);

            final bool isPremium = profile['is_premium'] ?? false;
            final bool isVip = profile['is_vip'] ?? false;
            final bool hasAccess = isPremium || isVip;

            final String? email = profile['email'];

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileEditPage(),
                        ),
                      );
                      _refreshPage();
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    nickname,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildBadge(badge),
                                  if (isVip) ...[
                                    const SizedBox(width: 6),
                                    _buildVipMark(),
                                  ] else if (isPremium) ...[
                                    const SizedBox(width: 6),
                                    _buildPremiumMark(),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: Colors.grey.shade100,
                          backgroundImage: imageUrl != null
                              ? NetworkImage(imageUrl)
                              : null,
                          child: imageUrl == null
                              ? const Icon(
                                  Icons.person,
                                  size: 38,
                                  color: Colors.grey,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _handlePassportTap(hasAccess),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A3D2F),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.menu_book,
                            color: Color(0xFFE5C100),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'passport_label'.tr(),
                            style: const TextStyle(
                              color: Color(0xFFE5C100),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          if (!hasAccess) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.lock_outline_rounded,
                              color: Color(0xFFE5C100),
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (email != null && email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 20),
                  GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _MenuTile(
                        title: 'my_travels'.tr(),
                        icon: Icons.public,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyTravelSummaryPage(),
                            ),
                          );
                          _refreshPage();
                        },
                      ),
                      _MenuTile(
                        title: 'map_settings'.tr(),
                        icon: Icons.map_outlined,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MapManagementPage(),
                            ),
                          );
                          _refreshPage();
                        },
                      ),
                      _MenuTile(
                        title: 'user_detail_title'.tr(),
                        icon: Icons.manage_accounts_outlined,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyUserDetailPage(),
                            ),
                          );
                          _refreshPage();
                        },
                      ),
                      _MenuTile(
                        title: 'support'.tr(),
                        icon: Icons.menu_book_outlined,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MySupportPage(),
                            ),
                          );
                          _refreshPage();
                        },
                      ),
                      _MenuTile(
                        title: 'settings'.tr(),
                        icon: Icons.settings_outlined,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MySettingsPage(),
                            ),
                          );
                          _refreshPage();
                        },
                      ),
                      GestureDetector(
                        onTap: _showTestRewardPopup, // 🎯 이제 누를 때마다 즉시 뜹니다!
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFF0F0F0)),
                          ),
                          child: Center(
                            child: Lottie.asset(
                              'assets/lottie/Earth globe rotating with Seamless loop animation.json',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVipMark() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF000000), Color(0xFF434343)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFFD700), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.stars, color: Color(0xFFFFD700), size: 14),
          SizedBox(width: 4),
          Text(
            'VIP',
            style: TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumMark() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFBC02D), Color(0xFFFFEB3B), Color(0xFFFBC02D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.5),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium, color: Color(0xFF795548), size: 14),
        ],
      ),
    );
  }

  Widget _buildBadge(Map<String, dynamic> badge) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badge['color'].withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badge['color'].withOpacity(0.3)),
      ),
      child: Text(
        (badge['title_key'] as String).tr(),
        style: TextStyle(
          color: badge['color'],
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const _MenuTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF0F0F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 32, color: Colors.blue.shade700),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
