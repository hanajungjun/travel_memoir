import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

// ✅ 점선을 그리기 위해 필요한 라이브러리야!
import 'package:flutter_svg/flutter_svg.dart';

class MySupportPage extends StatelessWidget {
  const MySupportPage({super.key});

  // ✅ URL 실행 공통 함수 (로직 사수!)
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
      backgroundColor: const Color(0xFFF6F6F6), // ✅ 1단계: 배경색 변경
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(27, 18, 27, 0), // ✅ 전체 여백
              // 🎯 [수정] ClampingScrollPhysics를 써야 화면에 딱 맞을 때 스크롤이 안 됩니다.
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  // ✅ 상단 18, 하단 27 패딩을 제외한 실제 가용 높이를 최소값으로 잡습니다.
                  minHeight: constraints.maxHeight - 18 - 0,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ❶ 2단계: 커스텀 상단바 (뒤로가기 + 제목)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              'support'.tr(),
                              style: AppTextStyles.pageTitle.copyWith(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textColor01,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),

                      // ❷ 3단계: 커다란 하얀색 카드 상자
                      // 🌟 Expanded를 추가해 IntrinsicHeight 내에서 가용한 공간을 꽉 채우게 합니다.
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(
                            25,
                            30,
                            25,
                            25,
                          ), // ✅ 카드 내부 여백
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            // 🌟 [디자인 수정] 위/아래를 끝으로 밀어내는 마법!
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // --- 상단 메뉴 뭉치 (자기들끼리 모여있게 Column으로 감싸줌) ---
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 1️⃣ 고객센터 섹션
                                  _SectionTitle('help_center'.tr()),
                                  _SupportTile(
                                    title: 'notice'.tr(),
                                    trailing: SvgPicture.asset(
                                      'assets/icons/ico_newwindow.svg',
                                    ),
                                    onTap: () => _launchURL(
                                      isKo
                                          ? 'https://hanajungjun.github.io/travel-memoir-docs/notice.html'
                                          : 'https://hanajungjun.github.io/travel-memoir-docs/notice_en.html',
                                    ),
                                  ),
                                  _SupportTile(
                                    title: 'get_help'.tr(),
                                    trailing: SvgPicture.asset(
                                      'assets/icons/ico_newwindow.svg',
                                    ),
                                    onTap: () => _launchURL(
                                      isKo
                                          ? 'https://hanajungjun.github.io/travel-memoir-docs/faq.html'
                                          : 'https://hanajungjun.github.io/travel-memoir-docs/faq_en.html',
                                    ),
                                  ),
                                  const _DashedDivider(),

                                  // 2️⃣ 개발정보 정보
                                  _SectionTitle('developer_info'.tr()),
                                  _SupportTile(
                                    title: 'contact_email'.tr(),
                                    trailing: const Text(
                                      'HajungTech@gmail.com',
                                      style: TextStyle(
                                        color: Color(0xFF289AEB),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    onTap: () => _launchURL(
                                      'mailto:HajungTech@gmail.com',
                                    ),
                                  ),
                                  _SupportTile(
                                    title: 'support_project'.tr(),
                                    trailing: SvgPicture.asset(
                                      'assets/icons/ico_newwindow.svg',
                                    ),
                                    onTap: () => _launchURL(
                                      isKo
                                          ? 'https://hanajungjun.github.io/travel-memoir-docs/support.html'
                                          : 'https://hanajungjun.github.io/travel-memoir-docs/support_en.html',
                                    ),
                                  ),
                                  const _DashedDivider(),

                                  // 3️⃣ 이용약관 섹션
                                  _SectionTitle('legal'.tr()),
                                  _SupportTile(
                                    title: 'privacy_policy'.tr(),
                                    trailing: SvgPicture.asset(
                                      'assets/icons/ico_newwindow.svg',
                                    ),
                                    onTap: () => _launchURL(
                                      isKo
                                          ? 'https://hanajungjun.github.io/travel-memoir-docs/'
                                          : 'https://hanajungjun.github.io/travel-memoir-docs/index_en.html',
                                    ),
                                  ),
                                  _SupportTile(
                                    title: 'terms_of_service'.tr(),
                                    trailing: SvgPicture.asset(
                                      'assets/icons/ico_newwindow.svg',
                                    ),
                                    onTap: () => _launchURL(
                                      isKo
                                          ? 'https://hanajungjun.github.io/travel-memoir-docs/terms.html'
                                          : 'https://hanajungjun.github.io/travel-memoir-docs/terms_en.html',
                                    ),
                                  ),
                                  _SupportTile(
                                    title: 'open_source_licenses'.tr(),
                                    trailing: SvgPicture.asset(
                                      'assets/icons/ico_user_more.svg',
                                    ),
                                    onTap: () =>
                                        showLicensePage(context: context),
                                  ),
                                ],
                              ),

                              // ❸ 하단 버전 정보 (맨 밑 오른쪽으로!)
                              Align(
                                alignment: Alignment.centerRight,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'app_brand_name'.tr(),
                                      style: AppTextStyles.sectionTitle
                                          .copyWith(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textColor01,
                                          ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'app_version_format'.tr(
                                        args: ['1.0.3', '100'],
                                      ),
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w300,
                                        color: const Color(0xFF949494),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// ✅ 아래 위젯들도 디자인에 맞춰서 싹 고쳤어!
// ---------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, right: 5, bottom: 7),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF2B2B2B),
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
      dense: true,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
      minVerticalPadding: 0,
      contentPadding: const EdgeInsets.symmetric(vertical: 3, horizontal: 5),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w300,
          color: Color(0xFF555555),
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 15, bottom: 20),
      child: CustomPaint(
        size: const Size(double.infinity, 1),
        painter: DashedLinePainter(),
      ),
    );
  }
}

class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double dashWidth = 3, dashSpace = 3, startX = 0;
    final paint = Paint()
      ..color = const Color(0xFFD9D9D9)
      ..strokeWidth = 1.2;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
