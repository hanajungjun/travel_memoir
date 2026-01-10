import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart'; // 추가

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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Text('landing_title'.tr(), style: AppTextStyles.landingTitle),
                  const SizedBox(height: 8),
                  Text(
                    'landing_subtitle'.tr(),
                    style: AppTextStyles.landingSubtitle,
                  ),
                  const Spacer(flex: 1),
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
