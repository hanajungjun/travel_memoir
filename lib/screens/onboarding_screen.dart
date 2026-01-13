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
    return IntroductionScreen(
      pages: [
        PageViewModel(
          title: "onboarding_title_1".tr(), // ✅ 번역 적용
          body: "onboarding_body_1".tr(), // ✅ 번역 적용
          image: const Center(
            child: Icon(Icons.map, size: 100, color: Colors.blue),
          ),
          decoration: const PageDecoration(
            titleTextStyle: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        PageViewModel(
          title: "onboarding_title_2".tr(), // ✅ 번역 적용
          body: "onboarding_body_2".tr(), // ✅ 번역 적용
          image: const Center(
            child: Icon(Icons.edit_location, size: 100, color: Colors.orange),
          ),
        ),
        PageViewModel(
          title: "onboarding_title_3".tr(), // ✅ 번역 적용
          body: "onboarding_body_3".tr(), // ✅ 번역 적용
          image: const Center(
            child: Icon(Icons.flight_takeoff, size: 100, color: Colors.green),
          ),
        ),
      ],
      onDone: () => _onIntroEnd(context),
      onSkip: () => _onIntroEnd(context),
      showSkipButton: true,
      skip: Text("skip".tr()), // ✅ 번역 적용
      next: const Icon(Icons.arrow_forward),
      done: Text(
        "start".tr(),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ), // ✅ 번역 적용
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
    );
  }
}
