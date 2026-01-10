import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // 추가
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class MySupportPage extends StatelessWidget {
  const MySupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('support'.tr()), // ✅ 번역 적용
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // =========================
            // 답변과 피드백
            // =========================
            _SectionTitle('help_and_feedback'.tr()), // ✅ 번역 적용
            _Divider(),

            _SupportTile(
              title: 'get_help'.tr(), // ✅ 번역 적용
              trailing: const Icon(Icons.open_in_new),
              onTap: () {
                // TODO: FAQ 링크
              },
            ),
            _Divider(),

            _SupportTile(
              title: 'rate_app'.tr(), // ✅ 번역 적용
              trailing: const Icon(Icons.open_in_new),
              onTap: () {
                // TODO: 스토어 링크
              },
            ),

            const SizedBox(height: 32),

            // =========================
            // 이용약관
            // =========================
            _SectionTitle('legal'.tr()), // ✅ 번역 적용
            _Divider(),

            _SupportTile(
              title: 'privacy_policy'.tr(), // ✅ 번역 적용
              trailing: const Icon(Icons.open_in_new),
              onTap: () {
                // TODO: 개인정보처리방침
              },
            ),
            _Divider(),

            _SupportTile(
              title: 'terms_of_service'.tr(), // ✅ 번역 적용
              trailing: const Icon(Icons.open_in_new),
              onTap: () {
                // TODO: 서비스 약관
              },
            ),
            _Divider(),

            _SupportTile(
              title: 'open_source_licenses'.tr(), // ✅ 번역 적용
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                showLicensePage(context: context);
              },
            ),
            _Divider(),

            _SupportTile(
              title: 'accessibility_policy'.tr(), // ✅ 번역 적용
              trailing: const Icon(Icons.open_in_new),
              onTap: () {
                // TODO: 접근성 정책
              },
            ),

            const SizedBox(height: 48),

            // =========================
            // 하단 버전 정보
            // =========================
            Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.wb_sunny_outlined,
                    size: 48,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'app_brand_name'.tr(),
                    style: AppTextStyles.sectionTitle,
                  ), // ✅ 브랜드명 번역
                  const SizedBox(height: 4),
                  // ✅ 버전 정보 포맷팅 번역 적용
                  Text(
                    'app_version_format'.tr(args: ['1.0.0', '100']),
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// 공통 위젯들
// =======================================================

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(text, style: AppTextStyles.pageTitle.copyWith(fontSize: 22)),
    );
  }
}

class _SupportTile extends StatelessWidget {
  final String title;
  final Widget trailing;
  final VoidCallback onTap;

  const _SupportTile({
    required this.title,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(title, style: AppTextStyles.body),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Divider(height: 1),
    );
  }
}
