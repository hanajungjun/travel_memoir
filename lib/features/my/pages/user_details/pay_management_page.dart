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

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
  }

  // ✅ 구독 상태 및 판매 상품 정보 가져오기
  Future<void> _loadSubscriptionStatus() async {
    try {
      // 직접 Purchases 부르는 대신 서비스 경유
      final offerings = await PaymentService.getOfferings();
      final customerInfo = await Purchases.getCustomerInfo();

      setState(() {
        _customerInfo = customerInfo;
        _offerings = offerings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // ✅ 결제 로직
  Future<void> _purchase() async {
    if (_offerings?.current?.monthly == null) return;

    // 1. 로딩 시작
    setState(() => _isLoading = true);

    try {
      final package = _offerings!.current!.monthly!;

      // 2. 우리가 만든 PaymentService 호출 (이 안에서 결제 + DB업데이트가 다 일어남!)
      bool success = await PaymentService.purchasePackage(package);

      if (success) {
        // 3. 성공했다면 구독 상태 다시 불러와서 화면 갱신
        await _loadSubscriptionStatus();

        // 기분 좋은 알림 하나 띄워주기
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('upgrade_success_msg'.tr())), // 번역에 추가 필요
          );
        }
      }
    } catch (e) {
      // 에러 처리
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 유료 유저 여부 확인 (Entitlement ID: 'premium' 기준)
    final bool isPremium =
        _customerInfo?.entitlements.all['premium']?.isActive ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text('payment_management'.tr()),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'subscription_info'.tr(),
                    style: AppTextStyles.pageTitle,
                  ),
                  const SizedBox(height: 16),

                  // ✅ 상태값: 유료(Active) vs 무료(None)
                  Text(
                    'current_subscription_status'.tr(
                      args: [
                        isPremium ? 'status_paid'.tr() : 'status_free'.tr(),
                      ],
                    ),
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: 32),

                  // ✅ 유료 유저일 경우: 다음 결제일 표시
                  if (isPremium) ...[
                    Text(
                      'next_billing_date'.tr(
                        args: [
                          _customerInfo
                                  ?.entitlements
                                  .all['premium']
                                  ?.expirationDate
                                  ?.substring(0, 10) ??
                              '-',
                        ],
                      ),
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 32),
                  ],

                  // ✅ 무료 유저일 경우: 결제 버튼 표시
                  if (!isPremium) ...[
                    Text(
                      'premium_benefit_desc'.tr(),
                      style: AppTextStyles.body,
                    ), // 혜택 설명
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _purchase,
                        // RevenueCat에서 가져온 현지 통화 가격 표시 (예: ₩4,900)
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
                        ),
                      ),
                    ),
                  ],

                  const Spacer(),

                  // ✅ 구매 복원 버튼 (애플 심사 필수)
                  Center(
                    child: TextButton(
                      onPressed: () async {
                        final restoredInfo = await Purchases.restorePurchases();
                        setState(() => _customerInfo = restoredInfo);
                      },
                      child: Text('restore_purchase'.tr()),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
