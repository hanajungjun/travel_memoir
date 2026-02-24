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
      appBar: AppBar(
        title: Text(
          'payment_management'.tr(),
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // ✅ 멤버십 변경 버튼 누르면 상점으로 이동
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShopPage()),
              );
            },
            child: Text(
              'change_membership'.tr(), // "멤버십변경"
              style: const TextStyle(
                color: Color(0xFF4A90E2),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // 💳 메인 상태 카드 (사진 디자인 반영)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 30,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // 1. 텍스트 영역
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  membershipTitle,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF333333),
                                  ),
                                ),
                                // ✅ 구독 중(VIP/Premium)일 때만 결제일 노출
                                if (hasActivePlan &&
                                    formattedDate.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'next_billing_date'.tr(
                                      args: [formattedDate],
                                    ),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            // 2. 버튼 영역
                            // ✅ 구독 중일 때만 '구독 취소' 버튼 노출 (일반 유저는 아예 안 보임)
                            if (hasActivePlan)
                              ElevatedButton(
                                onPressed: _handleCancelSubscription,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD9D9D9),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                                child: Text(
                                  'cancel_subscription_btn'.tr(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      // 구매 복원 버튼
                      _buildRestoreButton(),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildRestoreButton() {
    return Center(
      child: TextButton(
        onPressed: _handleRestore,
        child: Text(
          'restore_purchase'.tr(),
          style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
        ),
      ),
    );
  }
}
