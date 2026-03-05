import 'dart:io';
import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:confetti/confetti.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/services/payment_service.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/core/widgets/popup/app_toast.dart';
import 'package:travel_memoir/core/widgets/popup/app_dialogs.dart';
import 'package:travel_memoir/features/shop/page/shop_page.dart';

class PayManagementPage extends StatefulWidget {
  const PayManagementPage({super.key});

  @override
  State<PayManagementPage> createState() => _PayManagementPageState();
}

class _PayManagementPageState extends State<PayManagementPage>
    with WidgetsBindingObserver {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    WidgetsBinding.instance.addObserver(this);

    // ✅ 결제 성공 신호를 감시하는 리스너 추가
    PaymentService.refreshNotifier.addListener(_onPaymentRefresh);

    _loadDataFromDB();
  }

  @override
  void dispose() {
    // ✅ 페이지가 닫힐 때 리스너 해제 (메모리 누수 방지)
    PaymentService.refreshNotifier.removeListener(_onPaymentRefresh);
    _confettiController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ✅ 신호를 받았을 때 실행할 함수
  void _onPaymentRefresh() {
    if (mounted) {
      debugPrint("📡 [결제관리] 새로고침 신호 수신 - 데이터를 다시 로드합니다.");
      _loadDataFromDB();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadDataFromDB();
    }
  }

  // ✅ [데이터 로드] 레베뉴캣 동기화 없이 오직 DB 데이터만 사용
  Future<void> _loadDataFromDB() async {
    try {
      setState(() => _isLoading = true);
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. [제거] PaymentService.checkSubscriptionStatus()
      // 레베뉴캣 서버에 묻지 않고 바로 DB를 조회합니다.

      // 2. DB에서 현재 유저 정보 가져오기
      final data = await _supabase
          .from('users')
          .select('is_vip, vip_until, is_premium, premium_until')
          .eq('auth_uid', user.id)
          .single();

      if (mounted) {
        setState(() {
          // 3. DB에서 가져온 데이터 그대로 반영
          _userData = data;
          _isLoading = false;
        });

        // 4. (선택) DB 상으로 VIP나 Premium이면 폭죽 효과
        final bool isVip = data['is_vip'] ?? false;
        final bool isPremium = data['is_premium'] ?? false;

        if ((isVip || isPremium) &&
            _confettiController.state != ConfettiControllerState.playing) {
          _confettiController.play();
        }
      }
    } catch (e) {
      debugPrint("❌ 데이터 로드 실패: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ [해지 로직] 기존 소스 그대로 유지
  Future<void> _handleCancelSubscription() async {
    final bool? confirm = await AppDialogs.showConfirm(
      context: context,
      title: 'cancel_subscription_confirm_title',
      message: 'cancel_subscription_confirm_msg',
      confirmLabel: 'confirm_cancel',
      confirmColor: Colors.red,
    );

    if (confirm != true) return;

    final String cancelUrl = Platform.isIOS
        ? "https://apps.apple.com/account/subscriptions"
        : "https://play.google.com/store/account/subscriptions";

    final Uri url = Uri.parse(cancelUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // ✅ [복원 로직] 기존 소스 그대로 유지
  Future<void> _handleRestore() async {
    setState(() => _isLoading = true);
    await PaymentService.restorePurchases();
    await _loadDataFromDB(); // 복원 후 DB 다시 읽기

    if (mounted) {
      setState(() => _isLoading = false);
      final bool isNowPremium =
          (_userData?['is_vip'] ?? false) ||
          (_userData?['is_premium'] ?? false);
      if (isNowPremium) _confettiController.play();

      AppToast.show(
        context,
        isNowPremium
            ? 'restore_success_msg'.tr()
            : 'restore_no_history_msg'.tr(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isVip = _userData?['is_vip'] ?? false;
    final bool isPremium = _userData?['is_premium'] ?? false;
    final bool hasActivePlan = isVip || isPremium;

    String membershipTitle = 'free_member'.tr();
    String? expiryDateRaw;

    if (isVip) {
      membershipTitle = 'vip_member'.tr();
      expiryDateRaw = _userData?['vip_until'];
    } else if (isPremium) {
      membershipTitle = 'premium_member'.tr();
      expiryDateRaw = _userData?['premium_until'];
    }

    String formattedDate = expiryDateRaw != null
        ? DateFormat('yyyy. MM. dd').format(DateTime.parse(expiryDateRaw))
        : '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        bottom: false, // 하단 풀 바 디자인을 위해 false 설정
        child: Column(
          children: [
            // ❶ 스크롤 가능한 상단 영역
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(27, 18, 27, 27),
                      child: Column(
                        children: [
                          // 커스텀 상단바 (제목 중앙, 멤버십 변경 우측)
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Text(
                                  'payment_management'.tr(),
                                  style: AppTextStyles.pageTitle.copyWith(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textColor01,
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const ShopPage(),
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                    ),
                                    child: Text(
                                      'nav_shop'.tr(),
                                      style: const TextStyle(
                                        color: Color(0xFF289AEB),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                        decorationColor: Color(0xFF289AEB),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),

                          // 💳 메인 상태 카드
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(30, 20, 21, 20),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      membershipTitle,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2B2B2B),
                                      ),
                                    ),
                                    if (hasActivePlan &&
                                        formattedDate.isNotEmpty) ...[
                                      const SizedBox(height: 1),
                                      Text(
                                        'next_billing_date'.tr(
                                          args: [formattedDate],
                                        ),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w300,
                                          color: Color(0xFF7F7F7F),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (hasActivePlan)
                                  ElevatedButton(
                                    onPressed: _handleCancelSubscription,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFD5D5D5),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 15,
                                        vertical: 6,
                                      ),
                                    ),
                                    child: Text(
                                      'cancel_subscription_btn'.tr(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // ❷ 하단 고정 구매 복원 버튼 (Full Bar 디자인)
            GestureDetector(
              onTap: _isLoading ? null : _handleRestore,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    height: 58,
                    color: _isLoading
                        ? const Color(0xFFC2C2C2)
                        : const Color(0xFF454B54),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Color(0xFFFFFFFF),
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'restore_purchase'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  // 디바이스 하단 Safe Area 영역 색상 채우기
                  Container(
                    width: double.infinity,
                    height: MediaQuery.of(context).padding.bottom,
                    color: _isLoading
                        ? const Color(0xFFC2C2C2)
                        : const Color(0xFF454B54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
