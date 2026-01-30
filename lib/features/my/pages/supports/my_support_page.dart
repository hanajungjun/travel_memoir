import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class MySupportPage extends StatelessWidget {
  const MySupportPage({super.key});

  // ✅ URL 실행 공통 함수
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch $url');
      }
    } catch (e) {
      debugPrint('URL 실행 에러: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 현재 언어 확인
    final bool isKo = context.locale.languageCode == 'ko';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('support'.tr()),
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

            // 1️⃣ 고객지원 섹션
            _SectionTitle('help_center'.tr()),
            const _Divider(),
            _SupportTile(
              title: 'notice'.tr(),
              trailing: const Icon(
                Icons.open_in_new,
                size: 18,
                color: Colors.grey,
              ),
              onTap: () => _launchURL(
                isKo
                    ? 'https://hanajungjun.github.io/travel-memoir-docs/notice.html'
                    : 'https://hanajungjun.github.io/travel-memoir-docs/notice_en.html',
              ),
            ),
            const _Divider(),
            _SupportTile(
              title: 'get_help'.tr(),
              trailing: const Icon(
                Icons.open_in_new,
                size: 18,
                color: Colors.grey,
              ),
              onTap: () => _launchURL(
                isKo
                    ? 'https://hanajungjun.github.io/travel-memoir-docs/faq.html'
                    : 'https://hanajungjun.github.io/travel-memoir-docs/faq_en.html',
              ),
            ),

            const SizedBox(height: 32),

            // 2️⃣ 개발자 정보 (심사 안전 지대)
            _SectionTitle('developer_info'.tr()),
            const _Divider(),
            _SupportTile(
              title: 'contact_email'.tr(),
              trailing: const Text(
                'hanajungjun@gmail.com',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              onTap: () => _launchURL('mailto:hanajungjun@gmail.com'),
            ),
            const _Divider(),
            _SupportTile(
              title: 'support_project'.tr(), // "개발자 응원 및 프로젝트 지원"
              trailing: const Icon(
                Icons.chevron_right,
                size: 20,
                color: Colors.grey,
              ),
              onTap: () => _launchURL(
                isKo
                    ? 'https://hanajungjun.github.io/travel-memoir-docs/support.html'
                    : 'https://hanajungjun.github.io/travel-memoir-docs/support_en.html',
              ),
            ),

            const SizedBox(height: 32),

            // 3️⃣ 법적 고지 섹션
            _SectionTitle('legal'.tr()),
            const _Divider(),
            _SupportTile(
              title: 'privacy_policy'.tr(),
              trailing: const Icon(
                Icons.open_in_new,
                size: 18,
                color: Colors.grey,
              ),
              onTap: () => _launchURL(
                isKo
                    ? 'https://hanajungjun.github.io/travel-memoir-docs/'
                    : 'https://hanajungjun.github.io/travel-memoir-docs/index_en.html',
              ),
            ),
            const _Divider(),
            _SupportTile(
              title: 'terms_of_service'.tr(),
              trailing: const Icon(
                Icons.open_in_new,
                size: 18,
                color: Colors.grey,
              ),
              onTap: () => _launchURL(
                isKo
                    ? 'https://hanajungjun.github.io/travel-memoir-docs/terms.html'
                    : 'https://hanajungjun.github.io/travel-memoir-docs/terms_en.html',
              ),
            ),
            const _Divider(),
            _SupportTile(
              title: 'open_source_licenses'.tr(),
              trailing: const Icon(
                Icons.chevron_right,
                size: 20,
                color: Colors.grey,
              ),
              onTap: () => showLicensePage(context: context),
            ),
            const _Divider(),

            const SizedBox(height: 56),

            // 4️⃣ 하단 버전 정보 (이미지 삭제)
            Center(
              child: Column(
                children: [
                  Text(
                    'app_brand_name'.tr(),
                    style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'app_version_format'.tr(args: ['1.0.0', '100']),
                    style: AppTextStyles.caption.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// ✅ 내부 헬퍼 위젯 (에러 방지를 위해 하단에 포함)
// ---------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
        ),
      ),
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
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, color: Colors.black87),
      ),
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
      child: Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
    );
  }
}
