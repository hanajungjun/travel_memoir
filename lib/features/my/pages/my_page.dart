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

import 'package:flutter_svg/flutter_svg.dart';

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

      // 🛡️ 신규 유저 딜레이 대비 재시도 로직
      Map<String, dynamic>? profile;
      for (int i = 0; i < 3; i++) {
        profile = await Supabase.instance.client
            .from('users')
            .select()
            .eq('auth_uid', userId)
            .maybeSingle();
        if (profile != null) break;
        await Future.delayed(const Duration(milliseconds: 800));
      }

      final travelResult = await Supabase.instance.client
          .from('travels')
          .select('*')
          .eq('user_id', userId)
          .eq('is_completed', true)
          .order('created_at', ascending: false);

      return {
        'profile': profile,
        'completedTravels': travelResult ?? [],
        'travelCount': (travelResult as List?)?.length ?? 0,
      };
    } on PostgrestException catch (e) {
      debugPrint("❌ [MyPage] DB 오류: ${e.message}");
      return {'profile': null, 'completedTravels': [], 'travelCount': 0};
    } catch (e) {
      debugPrint("❌ [MyPage] 알 수 없는 오류: $e");
      return {'profile': null, 'completedTravels': [], 'travelCount': 0};
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
      backgroundColor: const Color(0xFFF6F6F6),
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
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('loading'.tr()),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _refreshPage,
                      child: Text('retry'.tr()),
                    ),
                  ],
                ),
              );
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

            // 🎯 [수정 시작] LayoutBuilder와 ConstrainedBox로 감싸 화면 크기에 대응합니다.
            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(), // 안넘칠 땐 고정되게
                  padding: EdgeInsets.fromLTRB(27, 27, 27, 15),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          constraints.maxHeight - 27 - 15, // 패딩 고려한 최소 높이
                    ),
                    child: IntrinsicHeight(
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
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(15),
                              child: Column(
                                children: [
                                  // 프로필 이미지 + 편집 아이콘
                                  Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      Container(
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                        ),
                                        child: CircleAvatar(
                                          radius: 50,
                                          backgroundColor: Color(0xFFE4E4E4),
                                          backgroundImage: imageUrl != null
                                              ? NetworkImage(imageUrl)
                                              : null,
                                          child: imageUrl == null
                                              ? SvgPicture.asset(
                                                  'assets/icons/ico_user.svg',
                                                  width: 45,
                                                  height: 47,
                                                )
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 15),
                                  // 닉네임과 칭호/배지
                                  // ✨ 닉네임 + VIP마크 (한 줄)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // ❶ [왼쪽] 투명한 마크 (무게 중심 맞추기용)
                                      if (isVip || isPremium)
                                        Opacity(
                                          opacity: 0,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              right: 10,
                                            ),
                                            child: isVip
                                                ? _buildVipMark()
                                                : _buildPremiumMark(),
                                          ),
                                        ),

                                      // ❷ [중앙] 실제 닉네임
                                      Text(
                                        nickname,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2B2B2B),
                                          letterSpacing: -0.5,
                                        ),
                                      ),

                                      // ❸ [오른쪽] 실제 마크
                                      if (isVip || isPremium)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 10,
                                          ),
                                          child: isVip
                                              ? _buildVipMark()
                                              : _buildPremiumMark(),
                                        ),
                                    ],
                                  ),

                                  // ✨ 뱃지만 따로 (중앙 정렬)
                                  Center(child: _buildBadge(badge)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 13),
                          Column(
                            children: [
                              _MenuTile(
                                title: 'my_travels'.tr(),
                                svgName: 'ico_menu01.svg', // 나의 여행
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const MyTravelSummaryPage(),
                                    ),
                                  );
                                  _refreshPage();
                                },
                              ),
                              _MenuTile(
                                title: 'map_settings'.tr(),
                                svgName: 'ico_menu02.svg', // 지도 설정
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
                                svgName: 'ico_menu03.svg', // 계정 관리
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
                                title: 'settings'.tr(),
                                svgName: 'ico_menu04.svg', // 설정
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
                              _MenuTile(
                                title: 'support'.tr(),
                                svgName: 'ico_menu05.svg', // 고객 지원
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
                                title: 'passport_label'.tr(),
                                svgName: 'ico_menu06.svg', // 내 여권
                                subtitle: '(${"premium_only_title".tr()})',
                                onTap: () => _handlePassportTap(hasAccess),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildVipMark() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFAC38),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/icons/ico_vip.svg', width: 9, height: 9),
          const SizedBox(width: 2),
          const Text(
            'VIP',
            style: TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumMark() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFF388E),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/icons/ico_vip.svg', width: 9, height: 9),
          const SizedBox(width: 2),
          const Text(
            'Premium',
            style: TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(Map<String, dynamic> badge) {
    return Text(
      (badge['title_key'] as String).tr(),
      style: const TextStyle(
        color: Color(0xFF888888),
        fontWeight: FontWeight.w300,
        fontSize: 14,
        letterSpacing: -0.5,
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String title;
  final String svgName;
  final VoidCallback onTap;
  final String? subtitle;
  const _MenuTile({
    required this.title,
    required this.svgName,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Align(
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/icons/$svgName',
                  width: 19,
                  height: 19,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2B2B2B),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(width: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF2B2B2B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
