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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: IntroductionScreen(
          pages: [
            // 📖 1. 일기 쓰기 (기록)
            PageViewModel(
              title: "onboarding_title_1".tr(),
              body: "onboarding_body_1".tr(),
              image: _buildImage(
                'assets/images/onboarding_diary.png',
                Icons.auto_stories,
                Colors.blue,
              ),
              decoration: _getPageDecoration(),
            ),

            // 📍 2. 지도 기록 (발자취)
            PageViewModel(
              title: "onboarding_title_2".tr(),
              body: "onboarding_body_2".tr(),
              image: _buildImage(
                'assets/images/onboarding_map.png',
                Icons.map_rounded,
                Colors.green,
              ),
              decoration: _getPageDecoration(),
            ),

            // ✨ 3. 추억 떠올리기 (AI 리포트)
            PageViewModel(
              title: "onboarding_title_3".tr(),
              body: "onboarding_body_3".tr(),
              image: _buildImage(
                'assets/images/onboarding_memory.png',
                Icons.auto_awesome_motion,
                Colors.amber,
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
          controlsPadding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 8.0,
          ),
          dotsDecorator: DotsDecorator(
            size: const Size.square(10.0),
            activeSize: const Size(20.0, 10.0),
            activeColor: AppColors.primary,
            color: Colors.black12,
            spacing: const EdgeInsets.symmetric(horizontal: 3.0),
            activeShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25.0),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ 이미지 위젯 빌더 (파일이 없으면 아이콘으로 대체)
  Widget _buildImage(String assetName, IconData backupIcon, Color color) {
    return Center(
      child: Image.asset(
        assetName,
        width: 280,
        errorBuilder: (context, error, stackTrace) =>
            Icon(backupIcon, size: 120, color: color),
      ),
    );
  }

  // ✅ 페이지 스타일 설정
  PageDecoration _getPageDecoration() {
    return PageDecoration(
      titleTextStyle: AppTextStyles.sectionTitle.copyWith(fontSize: 26),
      bodyTextStyle: AppTextStyles.body.copyWith(
        color: Colors.grey[600],
        height: 1.5,
      ),
      imagePadding: const EdgeInsets.only(top: 60),
      titlePadding: const EdgeInsets.only(top: 30, bottom: 12),
      bodyPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}
