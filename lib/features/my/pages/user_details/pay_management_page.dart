import 'dart:io';
import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:confetti/confetti.dart'; // ✅ 폭죽 효과

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/services/payment_service.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/core/widgets/popup/app_toast.dart';
import 'package:travel_memoir/core/widgets/popup/app_dialogs.dart';

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

  // ✅ 폭죽 컨트롤러
  late ConfettiController _confettiController;

  static const String _proEntitlementId = "PREMIUM ACCESS";
  static const String _vipEntitlementId = "VIP_ACCESS";

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    WidgetsBinding.instance.addObserver(this);
    _loadSubscriptionStatus();
  }

  @override
  void dispose() {
    _confettiController.dispose();
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
      debugPrint("❌ 결제 정보 로드 실패: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _purchase(Package package) async {
    setState(() => _isLoading = true);
    try {
      bool success = await PaymentService.purchasePackage(package);

      if (success) {
        await PaymentService.syncSubscriptionStatus();
        await _loadSubscriptionStatus();

        if (mounted) {
          // 🎊 진동 없이 화려한 폭죽만 발사!
          _confettiController.play();

          // AppDialogs.showDynamicIconAlert(
          //   context: context,
          //   title: 'congratulations'.tr(),
          //   message: 'upgrade_success_msg'.tr(),
          //   icon: Icons.celebration,
          //   iconColor: AppColors.primary,
          //   onClose: () =>
          //       Navigator.of(context).popUntil((route) => route.isFirst),
          // );
        }
        AppToast.show(context, 'upgrade_success_msg'.tr());
      }
    } catch (e) {
      debugPrint("❌ 결제 중 에러 발생: $e");
      if (mounted) AppToast.error(context, 'purchase_error_msg'.tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final bool isPro =
        _customerInfo?.entitlements.all[_proEntitlementId]?.isActive ?? false;
    final bool isVip =
        _customerInfo?.entitlements.all[_vipEntitlementId]?.isActive ?? false;
    final bool isPremium = isPro || isVip;

    final List<Package> subscriptionPackages =
        _offerings?.current?.availablePackages.where((p) {
          final id = p.identifier.toLowerCase();
          return p.packageType == PackageType.monthly ||
              p.packageType == PackageType.annual ||
              id.contains('vip');
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
      body: Stack(
        children: [
          _isLoading
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
                      _buildStatusCard(isPremium, isVip),
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

          // ✨ 브랜드 컬러 폭죽 위젯 (진동 없음)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: [
                AppColors.primary,
                const Color(0xFFFFD700),
                Colors.white,
                Colors.blueAccent,
              ],
              createParticlePath: _drawStar,
            ),
          ),
        ],
      ),
    );
  }

  Path _drawStar(Size size) {
    double degToRad(double deg) => deg * (Math.pi / 180.0);
    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);
    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(
        halfWidth + externalRadius * Math.cos(step),
        halfWidth + externalRadius * Math.sin(step),
      );
      path.lineTo(
        halfWidth + internalRadius * Math.cos(step + halfDegreesPerStep),
        halfWidth + internalRadius * Math.sin(step + halfDegreesPerStep),
      );
    }
    path.close();
    return path;
  }

  Widget _buildStatusCard(bool isPremium, bool isVip) {
    final activeEntitlement = isVip
        ? _customerInfo?.entitlements.all[_vipEntitlementId]
        : _customerInfo?.entitlements.all[_proEntitlementId];

    String? rawDate = activeEntitlement?.expirationDate;
    String formattedDate = rawDate != null
        ? DateFormat('yyyy. MM. dd').format(DateTime.parse(rawDate))
        : '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isVip
            ? const Color(0xFFFFF9E6)
            : (isPremium ? const Color(0xFFF0F7FF) : const Color(0xFFF8F9FA)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isVip
              ? Colors.amber.withOpacity(0.5)
              : (isPremium
                    ? AppColors.primary.withOpacity(0.3)
                    : Colors.transparent),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isVip
                    ? Icons.workspace_premium_rounded
                    : (isPremium
                          ? Icons.stars_rounded
                          : Icons.person_outline_rounded),
                color: isVip
                    ? Colors.amber[800]
                    : (isPremium ? AppColors.primary : Colors.grey),
              ),
              const SizedBox(width: 8),
              Text(
                isVip
                    ? 'VIP MEMBER'
                    : (isPremium ? 'premium_member'.tr() : 'free_member'.tr()),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isVip ? Colors.amber[900] : Colors.black87,
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
    bool isVipProduct = id.contains('vip');
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
            gradient: isVipProduct
                ? const LinearGradient(
                    colors: [Color(0xFF1A1A1A), Color(0xFFC5A028)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: !isVipProduct && isYearly ? AppColors.primary : Colors.white,
            border: Border.all(
              color: isVipProduct ? Colors.transparent : AppColors.primary,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isVipProduct
                ? [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (isVipProduct)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.workspace_premium,
                          color: Colors.amber,
                          size: 22,
                        ),
                      ),
                    Flexible(
                      child: Text(
                        package.storeProduct.title.split('(').first.trim(),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: (isVipProduct || isYearly)
                              ? Colors.white
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                package.storeProduct.priceString,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: (isVipProduct || isYearly)
                      ? Colors.white
                      : AppColors.primary,
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
            final bool isPremiumNow =
                (_customerInfo?.entitlements.all[_proEntitlementId]?.isActive ??
                    false) ||
                (_customerInfo?.entitlements.all[_vipEntitlementId]?.isActive ??
                    false);

            if (isPremiumNow) {
              _confettiController.play();
            }

            AppToast.show(
              context,
              isPremiumNow
                  ? 'restore_success_msg'.tr()
                  : 'restore_no_history_msg'.tr(),
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
