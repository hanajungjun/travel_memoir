import 'package:flutter/material.dart';
import '../features/intro/pages/intro_page.dart';
import '../supabase/supabase.dart';

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
    await SupabaseManager.initialize(); // 🔥 Supabase 초기화
    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 Supabase 초기화 전 로딩 화면
    if (!_initialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // 🔥 초기화 완료 후 실제 앱 실행
    return MaterialApp(
      title: "Travel Memoir",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const IntroPage(), // 앱 첫 화면
    );
  }
}
