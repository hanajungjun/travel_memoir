import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:travel_memoir/features/auth/login_page.dart';
import 'package:travel_memoir/app/app_shell.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  Future<void> _onIntroEnd(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);

    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => StreamBuilder<AuthState>(
          stream: Supabase.instance.client.auth.onAuthStateChange,
          builder: (context, snapshot) {
            final session = snapshot.data?.session;
            if (session == null) {
              return const LoginPage();
            }
            return const AppShell();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🌍 현재 언어 코드 가져오기 (ko, en 등)
    final String lang = context.locale.languageCode;
    debugPrint('🔥🔥🔥 현재 앱 언어 설정: $lang'); // 터미널에 이 문구가 뜹니다!
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: IntroductionScreen(
          pages: [
            // 📍 1. 여행 기록
            PageViewModel(
              title: "onboarding_title_1".tr(),
              body: "onboarding_body_1".tr(),
              // 언어별 이미지 경로 자동 생성 (예: assets/images/onboard/ko_onboard_1.png)
              image: _buildMockupImage(
                context,
                'assets/images/onboard/${lang}_onboard_1.png',
              ),
              decoration: _getPageDecoration(),
            ),

            // 📖 2. 일기 작성
            PageViewModel(
              title: "onboarding_title_2".tr(),
              body: "onboarding_body_2".tr(),
              image: _buildMockupImage(
                context,
                'assets/images/onboard/${lang}_onboard_2.png',
              ),
              decoration: _getPageDecoration(),
            ),

            // ✨ 3. 추억 보기
            PageViewModel(
              title: "onboarding_title_3".tr(),
              body: "onboarding_body_3".tr(),
              image: _buildMockupImage(
                context,
                'assets/images/onboard/${lang}_onboard_3.png',
              ),
              decoration: _getPageDecoration(),
            ),

            // 🌍 4. 여행 통계
            PageViewModel(
              title: "onboarding_title_4".tr(),
              body: "onboarding_body_4".tr(),
              image: _buildMockupImage(
                context,
                'assets/images/onboard/${lang}_onboard_4.png',
              ),
              decoration: _getPageDecoration(),
            ),
          ],
          onDone: () => _onIntroEnd(context),
          onSkip: () => _onIntroEnd(context),
          showSkipButton: true,
          skip: Text("skip".tr(), style: const TextStyle(color: Colors.grey)),
          next: const Icon(Icons.arrow_forward, color: AppColors.primary),
          done: Text(
            "start".tr(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          dotsDecorator: DotsDecorator(
            size: const Size.square(10.0),
            activeSize: const Size(20.0, 10.0),
            activeColor: AppColors.primary,
            color: Colors.black12,
            activeShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25.0),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ 이미지 크기 극대화 + 미디어쿼리 적용 빌더
  Widget _buildMockupImage(BuildContext context, String assetPath) {
    final double screenHeight = MediaQuery.sizeOf(context).height;

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.65, // 이미지를 화면의 65%까지 키움
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.image_not_supported,
              size: 50,
              color: Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  PageDecoration _getPageDecoration() {
    return PageDecoration(
      titleTextStyle: AppTextStyles.sectionTitle.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      bodyTextStyle: AppTextStyles.body.copyWith(
        color: Colors.grey[600],
        height: 1.4,
      ),
      imagePadding: const EdgeInsets.only(top: 10, bottom: 0),
      titlePadding: const EdgeInsets.only(top: 10, bottom: 8),
      bodyPadding: const EdgeInsets.symmetric(horizontal: 32),
      imageFlex: 6, // 이미지 영역 대폭 확대
      bodyFlex: 2, // 텍스트 영역 축소
    );
  }
}
