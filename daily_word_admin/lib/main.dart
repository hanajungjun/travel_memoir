import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/admin_home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://rjevhsseixukhghfkozl.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJqZXZoc3NlaXh1a2hnaGZrb3psIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3MDQ0NzQsImV4cCI6MjA3OTI4MDQ3NH0.pMPLn9QYg2RARl20FFiisUcKojOUOdY1_PS0kvxVx8Q',
  );

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Word Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF111111),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF63A9E6),
          brightness: Brightness.dark,
        ),
      ),
      home: const AdminHomePage(),
    );
  }
}
