import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/supabase/supabase.dart';
import 'package:travel_memoir/features/auth/login_page.dart';
import 'package:travel_memoir/app/app_shell.dart';
import 'package:travel_memoir/app/route_observer.dart';
import 'package:travel_memoir/screens/onboarding_screen.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:travel_memoir/app/text_theme_utils.dart';

class TravelMemoirApp extends StatefulWidget {
  final bool showOnboarding;

  const TravelMemoirApp({super.key, required this.showOnboarding});

  @override
  State<TravelMemoirApp> createState() => _TravelMemoirAppState();
}

class _TravelMemoirAppState extends State<TravelMemoirApp> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initSupabase();
  }

  Future<void> _initSupabase() async {
    await SupabaseManager.initialize();
    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Travel Memoir',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      navigatorObservers: [routeObserver],
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'NotoSansKR',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        textTheme: applyLetterSpacing(ThemeData.light().textTheme, -0.3),

        // ✅ 버튼 테마 설정 부분 수정
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            elevation: WidgetStateProperty.all(0), // 그림자 제거
            shadowColor: WidgetStateProperty.all(Colors.transparent),
            overlayColor: WidgetStateProperty.all(
              Colors.transparent,
            ), // 눌렀을 때 색상 변하는 층 제거
            // 🔥 핵심: 버튼 클릭 시 퍼지는 물결 애니메이션(Splash) 제거
            splashFactory: NoSplash.splashFactory,

            // 참고: 최신 버전에서는 MaterialStateProperty 대신 WidgetStateProperty 사용을 권장합니다.
          ),
        ),
      ),

      // ✅ [추가] 경로(Route) 설정
      // 여행 완료 후 돌아올 '지도' 역할을 합니다.
      routes: {
        '/travel_info': (context) => const AppShell(), // 메인 탭 화면으로 연결
      },

      // 🔥 핵심 로직: 초기화 -> 온보딩 -> 로그인 체크 순서
      home: !_initialized
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ) // 1. 초기화 중
          : widget.showOnboarding
          ? const OnboardingPage() // 2. 온보딩 안 봤으면 온보딩 먼저!
          : StreamBuilder<AuthState>(
              // 3. 온보딩 봤으면 로그인 상태 체크
              stream: Supabase.instance.client.auth.onAuthStateChange,
              builder: (context, snapshot) {
                final session = snapshot.data?.session;

                if (session == null) {
                  return const LoginPage(); // 🔐 로그인 안됨
                }
                return const AppShell(); // ✅ 로그인 완료
              },
            ),
    );
  }
}
