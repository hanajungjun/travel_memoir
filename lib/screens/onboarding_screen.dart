import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/features/auth/login_page.dart';
import 'package:travel_memoir/app/app_shell.dart';

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
    // Scaffold로 전체 레이아웃 뼈대를 잡고 SafeArea로 시스템 영역 침범을 막습니다.
    return Scaffold(
      backgroundColor: Colors.white, // 배경색을 지정하면 더 깔끔합니다.
      body: SafeArea(
        child: IntroductionScreen(
          pages: [
            PageViewModel(
              title: "onboarding_title_1".tr(),
              body: "onboarding_body_1".tr(),
              image: const Center(
                child: Icon(Icons.map, size: 100, color: Colors.blue),
              ),
              decoration: const PageDecoration(
                titleTextStyle: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                // 내부 콘텐츠 마진을 주어 화면 끝에 붙지 않게 합니다.
                bodyPadding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
              ),
            ),
            PageViewModel(
              title: "onboarding_title_2".tr(),
              body: "onboarding_body_2".tr(),
              image: const Center(
                child: Icon(
                  Icons.edit_location,
                  size: 100,
                  color: Colors.orange,
                ),
              ),
            ),
            PageViewModel(
              title: "onboarding_title_3".tr(),
              body: "onboarding_body_3".tr(),
              image: const Center(
                child: Icon(
                  Icons.flight_takeoff,
                  size: 100,
                  color: Colors.green,
                ),
              ),
            ),
          ],
          onDone: () => _onIntroEnd(context),
          onSkip: () => _onIntroEnd(context),
          showSkipButton: true,
          skip: Text("skip".tr()),
          next: const Icon(Icons.arrow_forward),
          done: Text(
            "start".tr(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          // 핵심: 하단 컨트롤러(점, 버튼) 영역의 패딩을 기기 환경에 맞게 자동 조절
          controlsPadding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 8.0,
          ),
          dotsDecorator: DotsDecorator(
            size: const Size.square(10.0),
            activeSize: const Size(20.0, 10.0),
            activeColor: Colors.blueAccent,
            color: Colors.black26,
            spacing: const EdgeInsets.symmetric(horizontal: 3.0),
            activeShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25.0),
            ),
          ),
        ),
      ),
    );
  }
}
