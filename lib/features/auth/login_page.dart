import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/app/app_shell.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

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
  // Login handlers
  // =====================
  Future<void> _loginWithKakao() async {
    try {
      final token = await UserApi.instance.loginWithKakaoAccount();
      debugPrint('🧨 KAKAO aud = ${parseJwt(token.idToken!)['aud']}');

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.kakao,
        idToken: token.idToken!,
      );
    } catch (e) {
      debugPrint('❌ Kakao login error: $e');
    }
  }

  Future<void> _loginWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn(
        scopes: ['email', 'profile'],
      ).signIn();

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

  Future<void> _loginWithEmail() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('이메일로 로그인', style: AppTextStyles.sectionTitle),
        content: TextField(
          controller: controller,
          style: AppTextStyles.body,
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

  // =====================
  // UI
  // =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),

              Text('Travel Memoir', style: AppTextStyles.title),
              const SizedBox(height: 12),
              Text(
                '여행의 순간을\n하루의 기록으로 남겨보세요.',
                style: AppTextStyles.bodyMuted,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              _loginButton(
                text: '카카오로 로그인',
                background: const Color(0xFFFEE500),
                textColor: Colors.black,
                onTap: _loginWithKakao,
              ),

              const SizedBox(height: 12),

              _loginButton(
                text: 'Google로 로그인',
                background: AppColors.surface,
                textColor: AppColors.textPrimary,
                onTap: _loginWithGoogle,
              ),

              if (Platform.isIOS) ...[
                const SizedBox(height: 12),
                _loginButton(
                  text: 'Apple로 로그인',
                  background: Colors.black,
                  textColor: Colors.white,
                  onTap: _loginWithApple,
                ),
              ],

              const SizedBox(height: 16),

              TextButton(
                onPressed: _loginWithEmail,
                child: Text('이메일로 로그인', style: AppTextStyles.bodyMuted),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loginButton({
    required String text,
    required Color background,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onTap,
        child: Text(text, style: AppTextStyles.button),
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
