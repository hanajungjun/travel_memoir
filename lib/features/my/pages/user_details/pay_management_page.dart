import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // 추가
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class PayManagementPage extends StatelessWidget {
  const PayManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('payment_management'.tr()), // ✅ 번역 적용
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              'subscription_info'.tr(),
              style: AppTextStyles.pageTitle,
            ), // ✅ 번역 적용
            const SizedBox(height: 16),

            // ✅ 상태값(유료/무료) 번역 대응
            Text(
              'current_subscription_status'.tr(args: ['status_paid'.tr()]),
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 32),

            // ✅ 날짜 포맷팅 번역 대응
            Text(
              'next_billing_date'.tr(args: ['2026. 02. 01']),
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: () {
                // 결제 정보 변경 페이지로 이동
              },
              child: Text('change_payment_info'.tr()), // ✅ 번역 적용
            ),
          ],
        ),
      ),
    );
  }
}
