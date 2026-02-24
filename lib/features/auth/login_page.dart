import 'dart:async';
import 'dart:io';
import 'package:travel_memoir/env.dart';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:travel_memoir/app/app_shell.dart';
import 'package:travel_memoir/services/payment_service.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/core/widgets/popup/app_toast.dart';
import 'package:travel_memoir/core/widgets/popup/app_dialogs.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final supabase = Supabase.instance.client;
  StreamSubscription<AuthState>? _authSub;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // ✅ [서버 스위치] 심사 모드 여부 상태값 추가
  bool _isReviewMode = false;

  @override
  void initState() {
    super.initState();

    // 🎯 1. 서버에서 심사 모드 여부 먼저 확인
    _checkReviewMode();

    _authSub = supabase.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;
      if (user == null) return;

      await supabase.from('users').upsert({
        'auth_uid': user.id,
        'provider': user.appMetadata['provider'] ?? 'email',
        'email': user.email,
        'provider_nickname':
            user.userMetadata?['name'] ??
            user.userMetadata?['full_name'] ??
            user.email?.split('@')[0],
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'auth_uid');

      // 🚨 2. [핵심 추가] RevenueCat에 로그인 알리기
      // 이 과정을 거쳐야 RevenueCat이 이 유저의 결제 내역을 정확히 불러옵니다.
      await PaymentService.init(user.id);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    });
  }

  // ✅ [로직] 수파베이스 app_config 테이블에서 스위치 상태 읽기
  Future<void> _checkReviewMode() async {
    try {
      final data = await supabase
          .from('app_config')
          .select('is_review_mode')
          .single();

      if (mounted) {
        setState(() {
          _isReviewMode = data['is_review_mode'] ?? false;
        });
      }
    } catch (e) {
      debugPrint("⚠️ 심사 모드 로드 실패 (기본값 false 사용): $e");
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- 로그인 로직 (기존과 동일) ---

  Future<void> _loginWithPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      AppToast.error(context, 'please_enter_id_pw'.tr());
      return;
    }
    setState(() => _isLoading = true);
    try {
      await supabase.auth.signInWithPassword(email: email, password: password);
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'login_failed'.tr());
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
        serverClientId: AppEnv.serverClientId,
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

    AppDialogs.showInput(
      context: context,
      title: 'email_login_title',
      hintText: 'email_hint',
      controller: controller,
      confirmLabel: 'send_link',
      onConfirm: (email) async {
        await supabase.auth.signInWithOtp(email: email);

        if (mounted) {
          Navigator.pop(context); // 팝업 닫기
          AppToast.show(context, 'check_email_link'.tr());
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
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
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 43),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 120),
                          Text(
                            'landing_title'.tr(),
                            style: AppTextStyles.landingTitle,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'landing_subtitle'.tr(),
                            style: AppTextStyles.landingSubtitle,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 27),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Column(
                        children: [
                          // ✅ 🎯 서버 값이 true일 때만 아이디/비번 칸 + OR 텍스트 노출
                          if (_isReviewMode) ...[
                            _buildIdPwFields(),
                            const SizedBox(height: 10),
                            _socialButton(
                              color: AppColors.travelingBlue,
                              text: 'login_sign_in'.tr(),
                              onTap: _isLoading ? () {} : _loginWithPassword,
                              textColor: AppColors.textColor02,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                "────────  OR  ────────",
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],

                          _socialButton(
                            iconAsset: 'assets/icons/kakao.png',
                            color: AppColors.buttonBg,
                            text: 'login_kakao'.tr(),
                            onTap: _loginWithKakao,
                          ),
                          const SizedBox(height: 10),
                          _socialButton(
                            iconAsset: 'assets/icons/google.png',
                            color: AppColors.buttonBg,
                            text: 'login_google'.tr(),
                            onTap: _loginWithGoogle,
                          ),

                          // ✅ 🎯 아이폰(iOS)에서만 애플 로그인 버튼 노출
                          if (Platform.isIOS) ...[
                            const SizedBox(height: 10),
                            _socialButton(
                              iconAsset: 'assets/icons/apple.png',
                              text: 'login_apple'.tr(),
                              onTap: _loginWithApple,
                              color: AppColors.buttonBg,
                            ),
                          ],

                          const SizedBox(height: 10),
                          _socialButton(
                            iconAsset: 'assets/icons/mail.png',
                            color: AppColors.buttonBg,
                            text: 'login_email'.tr(),
                            onTap: _loginWithEmail,
                          ),
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
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

  // --- UI 컴포넌트 (디자인 유지) ---

  Widget _buildIdPwFields() {
    return Column(
      children: [
        TextField(
          controller: _emailController,
          style: const TextStyle(color: AppColors.inputText),
          keyboardType: TextInputType.emailAddress,
          decoration: _inputDeco('아이디를 입력하세요'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passwordController,
          style: const TextStyle(color: AppColors.inputText),
          obscureText: true,
          decoration: _inputDeco('비밀번호를 입력하세요'),
        ),
      ],
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.inputText.withOpacity(0.2),
        fontSize: 14,
      ),
      filled: true,
      fillColor: AppColors.inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _socialButton({
    String? iconAsset,
    required Color color,
    required String text,
    required VoidCallback onTap,
    Color textColor = AppColors.textColor01,
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
              ? const BorderSide(color: AppColors.buttonBorder)
              : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (iconAsset != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Image.asset(
                  iconAsset,
                  width: 20,
                  height: 20,
                  fit: BoxFit.contain,
                ),
              ),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
