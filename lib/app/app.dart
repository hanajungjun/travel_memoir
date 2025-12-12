import 'package:flutter/material.dart';
import '../supabase/supabase.dart';
import 'app_shell.dart';

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
      title: "Travel Memoir",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: _initialized
          ? const AppShell() // ✅ 여기서 하단 탭 진입
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}
