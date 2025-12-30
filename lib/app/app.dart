import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase.dart';
import '../features/auth/login_page.dart';
import 'app_shell.dart';

// 🔥 추가
import 'route_observer.dart';

class TravelMemoirApp extends StatefulWidget {
  const TravelMemoirApp({super.key});

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

      // 🔥🔥🔥 핵심 (이거 없으면 didPopNext 안 탐)
      navigatorObservers: [routeObserver],

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      ),
      home: !_initialized
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : StreamBuilder<AuthState>(
              stream: Supabase.instance.client.auth.onAuthStateChange,
              builder: (context, snapshot) {
                final session = snapshot.data?.session;

                // 🔐 로그인 안됨
                if (session == null) {
                  return const LoginPage();
                }

                // ✅ 로그인 완료
                return const AppShell();
              },
            ),
    );
  }
}
