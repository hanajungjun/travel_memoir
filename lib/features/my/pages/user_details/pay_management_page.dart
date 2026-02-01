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

class _PayManagementPageState extends State<PayManagementPage>
    with WidgetsBindingObserver {
  CustomerInfo? _customerInfo;
  Offerings? _offerings;
  bool _isLoading = true;

  static const String _entitlementId = "TravelMemoir Pro";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSubscriptionStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadSubscriptionStatus();
    }
  }

  Future<void> _loadSubscriptionStatus() async {
    try {
      await PaymentService.syncSubscriptionStatus();
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
    // ✅ [테스트 모드] 서버 상태를 가져오되, 변수에는 강제로 false를 할당합니다.
    final bool serverPremiumStatus =
        _customerInfo?.entitlements.all[_entitlementId]?.isActive ?? false;

    // 🔥 대표님, 테스트가 끝나면 아래 줄을 지우거나 true/false를 서버 상태로 돌려주세요!
    bool isPremium = false;

    final List<Package> subscriptionPackages =
        _offerings?.current?.availablePackages.where((p) {
          final id = p.identifier.toLowerCase();
          return p.packageType == PackageType.monthly ||
              p.packageType == PackageType.annual ||
              id.contains('vip') ||
              id.contains('777');
        }).toList() ??
        [];

    subscriptionPackages.sort(
      (a, b) => a.storeProduct.price.compareTo(b.storeProduct.price),
    );

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
                  _buildStatusCard(isPremium), // 강제 false 상태 반영
                  const SizedBox(height: 35),

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
                    _buildCancelSection(),
                  ],

                  const SizedBox(height: 20),
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
    final id = package.identifier.toLowerCase();
    bool isVip = id.contains('vip') || id.contains('777');
    bool isYearly = package.packageType == PackageType.annual;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      width: double.infinity,
      child: InkWell(
        onTap: () => _purchase(package),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            gradient: isVip
                ? const LinearGradient(
                    colors: [Color(0xFF1A1A1A), Color(0xFFC5A028)],
                  )
                : null,
            color: !isVip && isYearly ? AppColors.primary : Colors.white,
            border: Border.all(
              color: isVip ? Colors.transparent : AppColors.primary,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isVip
                ? [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.2),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (isVip)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.workspace_premium,
                        color: Colors.amber,
                        size: 20,
                      ),
                    ),
                  Text(
                    package.storeProduct.title.split('(').first.trim(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: (isVip || isYearly)
                          ? Colors.white
                          : AppColors.primary,
                    ),
                  ),
                ],
              ),
              Text(
                package.storeProduct.priceString,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: (isVip || isYearly) ? Colors.white : AppColors.primary,
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
          await PaymentService.restorePurchases();
          await _loadSubscriptionStatus();
          if (mounted) {
            setState(() => _isLoading = false);
            // 복원 로직에서는 실제 서버 상태를 보여줍니다.
            final bool isPremiumNow =
                _customerInfo?.entitlements.all[_entitlementId]?.isActive ??
                false;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isPremiumNow
                      ? 'restore_success_msg'.tr()
                      : 'restore_no_history_msg'.tr(),
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
