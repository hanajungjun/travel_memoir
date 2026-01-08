import 'dart:async';
import 'package:flutter/foundation.dart';
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
    // 로그인 상태 변화 감지 및 유저 정보 DB 저장
    _authSub = supabase.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;
      if (user == null) return;

      await supabase.from('users').upsert({
        'auth_uid': user.id,
        'provider': user.appMetadata['provider'],
        'email': user.email,
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

  // ================= 로그인 로직 =================

  Future<void> _loginWithKakao() async {
    try {
      final token = await UserApi.instance.loginWithKakaoAccount();
      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.kakao,
        idToken: token.idToken!,
      );
    } catch (e) {
      print('카카오 로그인 에러: $e');
    }
  }

  Future<void> _loginWithGoogle() async {
    try {
      print("🚀 구글 로그인 시도 시작..."); // 이 로그가 먼저 나와야 합니다.

      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId:
            '440422476892-84jpfhl9udrlsnp7kpvpea5qn9bku6hr.apps.googleusercontent.com',
      );

      // 💡 이 줄에서 멈추는지 확인해야 합니다.
      final googleUser = await googleSignIn.signIn();

      print("🔍 googleUser 결과: $googleUser");

      if (googleUser != null) {
        print("✅ 구글 로그인 객체 획득 성공: ${googleUser.email}");
        final auth = await googleUser.authentication;

        await supabase.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: auth.idToken!,
          accessToken: auth.accessToken,
        );
      } else {
        print("❌ 사용자가 로그인창을 닫았습니다. (googleUser is null)");
      }
    } catch (e) {
      // 💡 중요: 에러가 나면 여기서 모든 상세 내용을 찍어줍니다.
      print('🚨 구글 로그인 최종 에러 발생: $e');
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
      print('애플 로그인 에러: $e');
    }
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
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('메일함에서 로그인 링크를 확인해주세요!')),
                );
              }
            },
            child: const Text('링크 보내기'),
          ),
        ],
      ),
    );
  }

  Future<void> _loginAsAdminTest() async {
    const adminUid = '11111111-1111-1111-1111-111111111111';
    await supabase.from('users').upsert({
      'auth_uid': adminUid,
      'provider': 'admin',
      'email': 'admin@travelmemoir.com',
      'role': 'admin',
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'auth_uid');
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AppShell()),
    );
  }

  // ================= UI 빌드 =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/login_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: Colors.blueGrey),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Text('나만의 여행 기록,', style: AppTextStyles.landingTitle),
                  const SizedBox(height: 8),
                  Text(
                    '당신만의 이야기로 채워지는 여행 일기',
                    style: AppTextStyles.landingSubtitle,
                  ),
                  const Spacer(flex: 1),

                  _socialButton(
                    icon: Icons.chat_bubble,
                    color: const Color(0xFFFEE500),
                    text: '카카오로 시작하기',
                    onTap: _loginWithKakao,
                  ),
                  const SizedBox(height: 12),
                  _socialButton(
                    icon: Icons.g_mobiledata,
                    color: Colors.white,
                    text: '구글로 시작하기',
                    onTap: _loginWithGoogle,
                  ),
                  const SizedBox(height: 12),
                  _socialButton(
                    icon: Icons.apple,
                    color: Colors.black,
                    text: '애플로 시작하기',
                    onTap: _loginWithApple,
                    textColor: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  _socialButton(
                    icon: Icons.email_outlined,
                    color: Colors.white,
                    text: '이메일로 시작하기',
                    onTap: _loginWithEmail,
                  ),

                  if (kDebugMode) ...[
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: _loginAsAdminTest,
                      child: const Text(
                        '관리자 테스트 로그인',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _socialButton({
    required IconData icon,
    required Color color,
    required String text,
    required VoidCallback onTap,
    Color textColor = Colors.black,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 0,
          side: color == Colors.white
              ? const BorderSide(color: Color(0xFFEEEEEE))
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
