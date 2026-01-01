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

        // 소셜 이름은 참고용
        'provider_nickname':
            user.userMetadata?['name'] ?? user.userMetadata?['full_name'],

        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'auth_uid');

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  // ================= 로그인 =================

  Future<void> _loginWithKakao() async {
    final token = await UserApi.instance.loginWithKakaoAccount();
    await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.kakao,
      idToken: token.idToken!,
    );
  }

  Future<void> _loginWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return;

    final auth = await googleUser.authentication;
    await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: auth.idToken!,
      accessToken: auth.accessToken,
    );
  }

  Future<void> _loginWithApple() async {
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
  }

  Future<void> _loginWithEmail() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('이메일로 시작하기'),
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
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('링크 보내기'),
          ),
        ],
      ),
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ===== Background Image =====
          Positioned.fill(
            child: Image.asset('assets/images/login_bg.png', fit: BoxFit.cover),
          ),

          // ===== Content =====
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 120),

                  // 타이틀
                  Text('나만의 여행 기록,', style: AppTextStyles.landingTitle),
                  const SizedBox(height: 8),
                  Text(
                    '당신만의 이야기로 채워지는 여행 일기',
                    style: AppTextStyles.landingSubtitle,
                  ),

                  const SizedBox(height: 48),

                  _loginButton(text: '카카오로 시작하기', onTap: _loginWithKakao),
                  const SizedBox(height: 12),

                  _loginButton(text: '구글로 시작하기', onTap: _loginWithGoogle),
                  const SizedBox(height: 12),

                  if (Platform.isIOS)
                    _loginButton(text: '애플로 시작하기', onTap: _loginWithApple),
                  const SizedBox(height: 12),

                  _loginButton(text: '이메일로 시작하기', onTap: _loginWithEmail),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= 공통 버튼 =================

  Widget _loginButton({required String text, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(text, style: AppTextStyles.loginButton),
      ),
    );
  }

  Widget _outlineButton({
    required Widget icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(text, style: AppTextStyles.loginButton),
          ],
        ),
      ),
    );
  }

  Widget _blob({required Color color, required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size),
      ),
    );
  }
}
