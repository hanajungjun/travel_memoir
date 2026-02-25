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

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                27,
                20,
                27,
                MediaQuery.of(context).padding.bottom + 32,
              ),
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
                          Stack(
                            alignment: Alignment.center, // 모든 자식을 일단 중앙에 모아요
                            clipBehavior:
                                Clip.none, // 마크가 닉네임 밖으로 튀어나가도 잘리지 않게!
                            children: [
                              // 1. 닉네임 (얘가 기준점이 되어 정중앙에 옵니다)
                              Text(
                                nickname,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2B2B2B),
                                  letterSpacing: -0.5,
                                ),
                              ),

                              // 2. VIP 마크 (닉네임 옆에 살짝 띄워서 배치)
                              if (isVip || isPremium)
                                Positioned(
                                  // 닉네임 중앙으로부터 오른쪽으로 (닉네임 길이에 따라 조절이 필요할 수 있음)
                                  // 하지만 가장 쉬운 건 아까 Row 방식을 쓰되, 투명한 가짜 박스를 왼쪽에 넣는 거예요.
                                  right: -50, // 이 수치를 조절해서 닉네임과의 간격을 맞춥니다
                                  child: isVip
                                      ? _buildVipMark()
                                      : _buildPremiumMark(),
                                ),
                            ],
                          ),

                          const SizedBox(height: 3), // 위아래 줄 사이 간격
                          // ✨ 뱃지만 따로 (중앙 정렬)
                          Center(child: _buildBadge(badge)),
                        ],
                      ),
                    ),
                  ),
                  // ✨ 여권 아래 나오던 이메일은 통일성을 위해 안쓸꺼임
                  // if (email != null && email.isNotEmpty) ...[
                  //   const SizedBox(height: 4),
                  //   Text(
                  //     email,
                  //     style: const TextStyle(color: Colors.grey, fontSize: 12),
                  //   ),
                  // ],
                  const SizedBox(height: 20),
                  Column(
                    children: [
                      _MenuTile(
                        title: 'my_travels'.tr(),
                        svgName: 'ico_menu01.svg', // 나의 여행
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
                      // 마지막 내 여권 메뉴 (이미지처럼 subtitle 추가)
                      _MenuTile(
                        title: 'passport_label'.tr(),
                        svgName: 'ico_menu06.svg', // 내 여권
                        subtitle: '(VIP 전용)',
                        onTap: () => _handlePassportTap(hasAccess),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFAC38), Color(0xFFFFAC38)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 직접 만드신 VIP 아이콘 넣기
          SvgPicture.asset(
            'assets/icons/ico_vip.svg', // 폴더 경로를 꼭 확인하세요!
            width: 9,
            height: 9,
          ),
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
  final String? subtitle; // 'VIP 전용' 같은 추가 문구를 위해 넣었어요
  const _MenuTile({
    required this.title,
    required this.svgName, // 필수 인자
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 13), // 메뉴 사이의 간격
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12), // 이미지처럼 부드러운 모서리
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
            // 🎯 요청하신 대로 SVG 아이콘 적용 (사이즈 19)
            SizedBox(
              width: 24, // 아이콘 영역 확보 (터치 및 정렬용)
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

            // 2. 메뉴 제목
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
