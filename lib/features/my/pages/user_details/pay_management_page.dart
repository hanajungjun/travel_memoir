import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
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

  // ✅ 아까 PaymentService에서 정한 이름과 반드시 똑같아야 합니다!
  static const String _entitlementId = "TravelMemoir Pro";

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
  }

  // ✅ 구독 상태 및 판매 상품 정보 가져오기
  Future<void> _loadSubscriptionStatus() async {
    try {
      // 🎯 PaymentService의 정적 메서드를 호출합니다.
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

  // ✅ 결제 로직
  Future<void> _purchase() async {
    // 현재 활성화된 월간 구독 패키지가 있는지 확인
    final package = _offerings?.current?.monthly;
    if (package == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('no_available_product'.tr())));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🎯 PaymentService를 통해 결제 + DB 업데이트까지 한방에!
      bool success = await PaymentService.purchasePackage(package);

      if (success) {
        await _loadSubscriptionStatus(); // 성공 후 화면 갱신
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

  @override
  Widget build(BuildContext context) {
    // ✅ 'premium'이 아니라 설정한 '_entitlementId'를 사용합니다.
    final bool isPremium =
        _customerInfo?.entitlements.all[_entitlementId]?.isActive ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text('payment_management'.tr()),
        backgroundColor: AppColors.primary,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    'subscription_info'.tr(),
                    style: AppTextStyles.pageTitle,
                  ),
                  const SizedBox(height: 20),

                  // 카드 형태의 상태 표시창
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isPremium
                          ? AppColors.primary.withOpacity(0.1)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isPremium
                            ? AppColors.primary
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'current_subscription_status'.tr(
                            args: [
                              isPremium
                                  ? 'status_paid'.tr()
                                  : 'status_free'.tr(),
                            ],
                          ),
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isPremium) ...[
                          const SizedBox(height: 12),
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
                            style: AppTextStyles.body,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 무료 유저에게만 결제 버튼 표시
                  if (!isPremium) ...[
                    Text(
                      'premium_benefit_desc'.tr(),
                      style: AppTextStyles.body.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _purchase,
                        child: Text(
                          'upgrade_to_premium'.tr(
                            args: [
                              _offerings
                                      ?.current
                                      ?.monthly
                                      ?.storeProduct
                                      .priceString ??
                                  '',
                            ],
                          ),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),

                  // 구매 복원 버튼 (애플 심사 필수)
                  Center(
                    child: TextButton(
                      onPressed: () async {
                        setState(() => _isLoading = true);
                        // 🎯 서비스의 복원 기능을 사용하여 DB까지 동기화합니다.
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
                        style: const TextStyle(
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
