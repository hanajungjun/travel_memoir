import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/services/payment_service.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class PayManagementPage extends StatefulWidget {
  const PayManagementPage({super.key});

  @override
  State<PayManagementPage> createState() => _PayManagementPageState();
}

class _PayManagementPageState extends State<PayManagementPage> {
  CustomerInfo? _customerInfo;
  Offerings? _offerings;
  bool _isLoading = true;

  // RevenueCat에서 설정한 Entitlement ID
  static const String _entitlementId = "TravelMemoir Pro";

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
  }

  /// ✅ 구독 상태 및 판매 정보 로드
  Future<void> _loadSubscriptionStatus() async {
    try {
      final offerings = await PaymentService.getOfferings();
      final customerInfo = await Purchases.getCustomerInfo();

      if (mounted) {
        setState(() {
          _offerings = offerings;
          _customerInfo = customerInfo;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ 정보 로드 실패: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ✅ [추가됨] 결제 로직
  Future<void> _purchase() async {
    // 월간 패키지 가져오기
    final package = _offerings?.current?.monthly;
    if (package == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('no_available_product'.tr())));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // PaymentService를 통해 결제 + DB 업데이트
      bool success = await PaymentService.purchasePackage(package);

      if (success) {
        await _loadSubscriptionStatus(); // 성공 시 상태 새로고침
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('upgrade_success_msg'.tr())));
        }
      }
    } catch (e) {
      debugPrint("❌ 결제 과정 오류: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ✅ 구독 취소 로직 (테스트 및 실제용)
  Future<void> _handleCancelSubscription() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('cancel_subscription_confirm_title'.tr()),
        content: Text('cancel_subscription_confirm_msg'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'cancel'.tr(),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'confirm_cancel'.tr(),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      // 1. DB 상태 업데이트
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client
            .from('users')
            .update({
              'is_premium': false,
              'subscription_status': 'none',
              'premium_until': null,
              'premium_since': null,
            })
            .eq('auth_uid', user.id);
      }

      // 2. 실제 스토어 구독 관리 페이지로 이동
      const String appleSubscriptionUrl =
          "https://apps.apple.com/account/subscriptions";
      final Uri url = Uri.parse(appleSubscriptionUrl);

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }

      await _loadSubscriptionStatus();
    } catch (e) {
      debugPrint("❌ 취소 과정 오류: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPremium =
        _customerInfo?.entitlements.all[_entitlementId]?.isActive ?? false;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'payment_management'.tr(),
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'subscription_info'.tr(),
                    style: AppTextStyles.pageTitle,
                  ),
                  const SizedBox(height: 20),

                  // 구독 상태 카드
                  _buildStatusCard(isPremium),

                  const SizedBox(height: 40),

                  // 상황별 버튼 배치
                  if (!isPremium) ...[
                    _buildUpgradeButton(),
                  ] else ...[
                    _buildCancelSection(),
                  ],

                  const SizedBox(height: 30),
                  _buildRestoreButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard(bool isPremium) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isPremium ? const Color(0xFFF0F7FF) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPremium
              ? AppColors.primary.withOpacity(0.3)
              : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPremium ? Icons.stars_rounded : Icons.person_outline_rounded,
                color: isPremium ? AppColors.primary : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                isPremium ? 'premium_member'.tr() : 'free_member'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (isPremium) ...[
            const SizedBox(height: 16),
            Text(
              'next_billing_date'.tr(
                args: [
                  _customerInfo
                          ?.entitlements
                          .all[_entitlementId]
                          ?.expirationDate
                          ?.substring(0, 10) ??
                      '-',
                ],
              ),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpgradeButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        onPressed: _purchase,
        child: Text(
          'upgrade_to_premium'.tr(
            args: [
              _offerings?.current?.monthly?.storeProduct.priceString ?? '',
            ],
          ),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildCancelSection() {
    return Column(
      children: [
        const Divider(height: 60),
        Center(
          child: TextButton(
            onPressed: _handleCancelSubscription,
            child: Text(
              'cancel_subscription'.tr(),
              style: const TextStyle(
                color: Colors.grey,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRestoreButton() {
    return Center(
      child: TextButton(
        onPressed: () async {
          setState(() => _isLoading = true);
          bool success = await PaymentService.restorePurchases();
          await _loadSubscriptionStatus();
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  success
                      ? 'restore_success_msg'.tr()
                      : 'restore_fail_msg'.tr(),
                ),
              ),
            );
          }
        },
        child: Text(
          'restore_purchase'.tr(),
          style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
        ),
      ),
    );
  }
}
