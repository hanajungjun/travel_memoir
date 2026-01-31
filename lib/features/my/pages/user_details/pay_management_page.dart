import 'dart:io';

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

  // RevenueCat Entitlement ID
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

  /// ✅ 결제 로직 (에러 핸들링 포함)
  Future<void> _purchase(Package package) async {
    setState(() => _isLoading = true);
    try {
      bool success = await PaymentService.purchasePackage(package);
      if (success) {
        await _loadSubscriptionStatus();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('upgrade_success_msg'.tr())));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('purchase_error_msg'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ✅ 구독 취소 (iOS/Android 분기 처리)
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

    final String cancelUrl = Platform.isIOS
        ? "https://apps.apple.com/account/subscriptions"
        : "https://play.google.com/store/account/subscriptions";

    final Uri url = Uri.parse(cancelUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPremium =
        _customerInfo?.entitlements.all[_entitlementId]?.isActive ?? false;

    // 🔥 [핵심 필터] 코인, 지도 패키지는 제외하고 '월간/연간' 구독 상품만 추출
    final List<Package> subscriptionPackages =
        _offerings?.current?.availablePackages
            .where(
              (p) =>
                  p.packageType == PackageType.monthly ||
                  p.packageType == PackageType.annual,
            )
            .toList() ??
        [];

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

                  // 1. 현재 구독 상태 카드
                  _buildStatusCard(isPremium),

                  const SizedBox(height: 40),

                  // 2. 미구독 시 구독 플랜 노출 (코인/지도 없음)
                  if (!isPremium) ...[
                    Text(
                      'choose_plan'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...subscriptionPackages
                        .map((p) => _buildPackageCard(p))
                        .toList(),
                  ] else ...[
                    // 3. 구독 중일 때만 취소 섹션 노출
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
    String? rawDate =
        _customerInfo?.entitlements.all[_entitlementId]?.expirationDate;
    String formattedDate = rawDate != null
        ? DateFormat('yyyy. MM. dd').format(DateTime.parse(rawDate))
        : '-';

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
              'next_billing_date'.tr(args: [formattedDate]),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPackageCard(Package package) {
    bool isYearly = package.packageType == PackageType.annual;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      width: double.infinity,
      child: InkWell(
        onTap: () => _purchase(package),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isYearly ? AppColors.primary : Colors.white,
            border: Border.all(color: AppColors.primary),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                package.storeProduct.title.split('(').first,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isYearly ? Colors.white : AppColors.primary,
                ),
              ),
              Text(
                package.storeProduct.priceString,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isYearly ? Colors.white : AppColors.primary,
                ),
              ),
            ],
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

          // 1. 일단 스토어에 복원 요청을 보냅니다.
          await PaymentService.restorePurchases();

          // 2. 최신 구독 상태를 다시 로드합니다. (이게 핵심!)
          await _loadSubscriptionStatus();

          if (mounted) {
            setState(() => _isLoading = false);

            // 3. [핵심 로직] 함수 성공 여부가 아니라, '실제 권한'이 생겼는지 확인합니다.
            final bool isPremiumNow =
                _customerInfo?.entitlements.all[_entitlementId]?.isActive ??
                false;

            if (isPremiumNow) {
              // 진짜로 살려낼 내역이 있었을 때
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('restore_success_msg'.tr())),
              );
            } else {
              // 내역이 없거나, 중간에 취소해서 프리미엄이 안 됐을 때
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('restore_no_history_msg'.tr())),
              );
            }
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
