import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel_memoir/app/app_shell.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final supabase = Supabase.instance.client;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();

    _authSub = supabase.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;
      if (user == null) return;

      debugPrint('🔥 AUTH UID = ${user.id}');

      await supabase.from('users').upsert({
        'auth_uid': user.id,
        'provider': user.appMetadata['provider'],
        'email': user.email,
        'nickname':
            user.userMetadata?['name'] ?? user.userMetadata?['full_name'],
        'profile_image': user.userMetadata?['avatar_url'],
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'auth_uid');

      _goToMain();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _goToMain() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AppShell()),
    );
  }

  // =====================
  // 🟡 Kakao SDK + Supabase Auth
  // =====================
  Future<void> _loginWithKakao() async {
    try {
      final token = await UserApi.instance.loginWithKakaoAccount();

      // 🔴 aud 찍는 줄 (이거만 보면 됨)
      debugPrint('🧨 KAKAO aud = ${parseJwt(token.idToken!)['aud']}');

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.kakao,
        idToken: token.idToken!,
      );
    } catch (e) {
      debugPrint('❌ Kakao login error: $e');
    }
  }

  // =====================
  // 🔵 Google SDK
  // =====================
  Future<void> _loginWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final auth = await googleUser.authentication;

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: auth.idToken!,
        accessToken: auth.accessToken,
      );
    } catch (e) {
      debugPrint('❌ Google login error: $e');
    }
  }

  // =====================
  // ⚪ Apple SDK
  // =====================
  Future<void> _loginWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: credential.identityToken!,
      );
    } catch (e) {
      debugPrint('❌ Apple login error: $e');
    }
  }

  // =====================
  // 📧 Email
  // =====================
  Future<void> _loginWithEmail() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('이메일로 로그인'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'email@example.com'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              await supabase.auth.signInWithOtp(email: controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('로그인 링크 보내기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Text(
                'Travel Memoir',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              _bigButton(
                text: '카카오로 로그인',
                color: const Color(0xFFFEE500),
                textColor: Colors.black,
                onTap: _loginWithKakao,
              ),
              const SizedBox(height: 12),
              _bigButton(text: 'Google로 로그인', onTap: _loginWithGoogle),
              const SizedBox(height: 12),
              if (Platform.isIOS)
                _bigButton(text: 'Apple로 로그인', onTap: _loginWithApple),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loginWithEmail,
                child: const Text('이메일로 로그인'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bigButton({
    required String text,
    required VoidCallback onTap,
    Color? color,
    Color? textColor,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
        ),
        onPressed: onTap,
        child: Text(text, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

// =====================
// JWT 파싱
// =====================
Map<String, dynamic> parseJwt(String token) {
  final parts = token.split('.');
  final payload = parts[1];
  final normalized = base64.normalize(payload);
  final decoded = utf8.decode(base64.decode(normalized));
  return json.decode(decoded);
}
