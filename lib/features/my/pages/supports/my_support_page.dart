import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart'; // 패키지 추가 필수
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class MySupportPage extends StatelessWidget {
  const MySupportPage({super.key});

  // URL을 외부 브라우저로 열기 위한 공통 함수
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      debugPrint('URL 실행 에러: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
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

            // ✅ 공지사항 버튼 (맨 위로 이동)
            _SupportTile(
              title: 'notice'.tr(), // 번역 파일에 'notice' 추가 필요
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _launchURL(
                'https://hanajungjun.github.io/travel-memoir-docs/notice.html',
              ),
            ),
            _Divider(),

            _SupportTile(
              title: 'get_help'.tr(),
              trailing: const Icon(Icons.open_in_new),
              onTap: () {
                // FAQ나 고객센터 링크가 있다면 여기에 넣으세요.
                _launchURL(
                  'https://hanajungjun.github.io/travel-memoir-docs/faq.html',
                );
              },
            ),
            _Divider(),

            _SupportTile(
              title: 'rate_app'.tr(),
              trailing: const Icon(Icons.open_in_new),
              onTap: () {
                // TODO: 실제 스토어 출시 후 스토어 링크로 교체하세요.
                // _launchURL('market://details?id=com.hanajungjun.travelmemoir');
              },
            ),

            const SizedBox(height: 32),

            // =========================
            // 이용약관 및 법적 고지 섹션
            // =========================
            _SectionTitle('legal'.tr()),
            _Divider(),

            _SupportTile(
              title: 'privacy_policy'.tr(),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _launchURL(
                'https://hanajungjun.github.io/travel-memoir-docs/',
              ),
            ),
            _Divider(),

            _SupportTile(
              title: 'terms_of_service'.tr(),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _launchURL(
                'https://hanajungjun.github.io/travel-memoir-docs/terms.html',
              ),
            ),
            _Divider(),

            _SupportTile(
              title: 'open_source_licenses'.tr(),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                showLicensePage(context: context);
              },
            ),
            _Divider(),

            const SizedBox(height: 48),

            // =========================
            // 하단 브랜드 및 버전 정보
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
                  ),
                  const SizedBox(height: 4),
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
// 내부 위젯들 (SectionTitle, SupportTile, Divider)
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
