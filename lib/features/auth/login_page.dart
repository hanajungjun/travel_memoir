import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

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

  // ✅ 비밀번호 로그인을 위한 컨트롤러 및 상태 추가
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _authSub = supabase.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;
      if (user == null) return;

      // ✅ 유저 정보 저장 (비번 로그인 시 provider는 'email'로 저장됨)
      await supabase.from('users').upsert({
        'auth_uid': user.id,
        'provider': user.appMetadata['provider'] ?? 'email',
        'email': user.email,
        'provider_nickname':
            user.userMetadata?['name'] ??
            user.userMetadata?['full_name'] ??
            user.email?.split('@')[0], // 닉네임 없을 시 이메일 앞자리
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ✅ [신규] 비밀번호 로그인 (리뷰어용)
  Future<void> _loginWithPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('please_enter_id_pw'.tr()),
        ), // "아이디와 비밀번호를 입력해주세요"
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await supabase.auth.signInWithPassword(email: email, password: password);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('login_failed'.tr())), // "로그인 실패"
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithKakao() async {
    try {
      final token = await UserApi.instance.loginWithKakaoAccount();
      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.kakao,
        idToken: token.idToken!,
      );
    } catch (e) {
      debugPrint('Kakao Login Error: $e');
    }
  }

  Future<void> _loginWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId:
            '440422476892-84jpfhl9udrlsnp7kpvpea5qn9bku6hr.apps.googleusercontent.com',
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser != null) {
        final auth = await googleUser.authentication;
        await supabase.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: auth.idToken!,
          accessToken: auth.accessToken,
        );
      }
    } catch (e) {
      debugPrint('Google Login Error: $e');
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
      debugPrint('Apple Login Error: $e');
    }
  }

  Future<void> _loginWithEmail() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('email_login_title'.tr()),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'email_hint'.tr()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              await supabase.auth.signInWithOtp(email: controller.text.trim());
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('check_email_link'.tr())),
                );
              }
            },
            child: Text('send_link'.tr()),
          ),
        ],
      ),
    );
  }

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
            child: SingleChildScrollView(
              // ✅ 키보드 노출 시 오버플로우 방지
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 80),
                    Text(
                      'landing_title'.tr(),
                      style: AppTextStyles.landingTitle,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'landing_subtitle'.tr(),
                      style: AppTextStyles.landingSubtitle,
                    ),
                    const SizedBox(height: 40),

                    // ✅ [추가] 이메일/비밀번호 입력 필드
                    _buildIdPwFields(),
                    const SizedBox(height: 16),

                    // ✅ [추가] 일반 로그인 버튼
                    _socialButton(
                      icon: Icons.login,
                      color: AppColors.travelingBlue,
                      text: 'login_sign_in'.tr(), // "로그인"
                      onTap: _isLoading ? () {} : _loginWithPassword,
                      textColor: Colors.white,
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        "────────  OR  ────────",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),

                    // ✅ 기존 소셜 버튼들
                    _socialButton(
                      icon: Icons.chat_bubble,
                      color: const Color(0xFFFEE500),
                      text: 'login_kakao'.tr(),
                      onTap: _loginWithKakao,
                    ),
                    const SizedBox(height: 12),
                    _socialButton(
                      icon: Icons.g_mobiledata,
                      color: Colors.white,
                      text: 'login_google'.tr(),
                      onTap: _loginWithGoogle,
                    ),
                    const SizedBox(height: 12),
                    _socialButton(
                      icon: Icons.apple,
                      color: Colors.black,
                      text: 'login_apple'.tr(),
                      onTap: _loginWithApple,
                      textColor: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    _socialButton(
                      icon: Icons.email_outlined,
                      color: Colors.white,
                      text: 'login_email'.tr(),
                      onTap: _loginWithEmail,
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  // ✅ 입력창 스타일 위젯
  Widget _buildIdPwFields() {
    return Column(
      children: [
        TextField(
          controller: _emailController,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.emailAddress,
          decoration: _inputDeco('Email (ID)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          style: const TextStyle(color: Colors.white),
          obscureText: true,
          decoration: _inputDeco('Password'),
        ),
      ],
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white60, fontSize: 14),
      filled: true,
      fillColor: Colors.black.withOpacity(0.3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
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
