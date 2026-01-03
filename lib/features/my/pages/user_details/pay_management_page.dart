import 'package:flutter/material.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class PayManagementPage extends StatelessWidget {
  const PayManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('결제 관리'),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text('구독 정보', style: AppTextStyles.pageTitle),
            const SizedBox(height: 16),
            Text('현재 구독 상태: 유료', style: AppTextStyles.body),
            const SizedBox(height: 32),
            Text('다음 결제일: 2026년 2월 1일', style: AppTextStyles.body),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // 결제 정보 변경 페이지로 이동
              },
              child: const Text('결제 정보 변경'),
            ),
          ],
        ),
      ),
    );
  }
}
