import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // ✅ 아이폰 스위치 쓰려면 필요해!
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/screens/onboarding_screen.dart';

import 'package:flutter_svg/flutter_svg.dart'; // 👈 이 한 줄을 맨 위에 추가!

class MySettingsPage extends StatefulWidget {
  const MySettingsPage({super.key});

  @override
  State<MySettingsPage> createState() => _MySettingsPageState();
}

class _MySettingsPageState extends State<MySettingsPage> {
  bool _notificationEnabled = true;
  bool _marketingEnabled = false;
  bool _isLoading = false;

  String get _userId => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    try {
      final userData = await Supabase.instance.client
          .from('users')
          .select('is_push_enabled, is_marketing_enabled')
          .eq('auth_uid', _userId)
          .single();

      setState(() {
        _notificationEnabled = userData['is_push_enabled'] ?? true;
        _marketingEnabled = userData['is_marketing_enabled'] ?? false;
      });

      await prefs.setBool('notification_enabled', _notificationEnabled);
      await prefs.setBool('marketing_enabled', _marketingEnabled);
    } catch (e) {
      debugPrint("❌ DB 설정 로드 실패, 로컬 데이터 사용: $e");
      setState(() {
        _notificationEnabled = prefs.getBool('notification_enabled') ?? true;
        _marketingEnabled = prefs.getBool('marketing_enabled') ?? false;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleNotification(bool value) async {
    setState(() => _notificationEnabled = value);
    try {
      await Supabase.instance.client
          .from('users')
          .update({'is_push_enabled': value})
          .eq('auth_uid', _userId);

      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: value,
            badge: value,
            sound: value,
          );

      if (value) {
        await FirebaseMessaging.instance.subscribeToTopic('all_users');
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic('all_users');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notification_enabled', value);
    } catch (e) {
      debugPrint("❌ 알림 설정 업데이트 실패: $e");
    }
  }

  Future<void> _toggleMarketing(bool value) async {
    setState(() => _marketingEnabled = value);
    try {
      await Supabase.instance.client
          .from('users')
          .update({
            'is_marketing_enabled': value,
            'marketing_accepted_at': value
                ? DateTime.now().toIso8601String()
                : null,
          })
          .eq('auth_uid', _userId);

      if (value) {
        await FirebaseMessaging.instance.subscribeToTopic('marketing');
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic('marketing');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('marketing_enabled', value);
    } catch (e) {
      debugPrint("❌ 마케팅 설정 업데이트 실패: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6), // ✅ 1단계: 배경색 변경
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  27,
                  18,
                  27,
                  27,
                ), // ✅ 1단계: 여백 변경
                child: Column(
                  children: [
                    // ✅ 2단계: 커스텀 상단바 디자인
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            'settings'.tr(),
                            style: AppTextStyles.pageTitle.copyWith(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textColor01,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),

                    // 🌍 언어 변경 (카드 스타일)
                    _SettingCard(
                      title: 'language'.tr(),
                      trailingText: context.locale.languageCode == 'ko'
                          ? '한국어'
                          : 'English',
                      iconColor: AppColors.travelingBlue, // 👈 more버튼 색상 변경
                      onTap: () {
                        if (context.locale.languageCode == 'ko') {
                          context.setLocale(const Locale('en'));
                        } else {
                          context.setLocale(const Locale('ko'));
                        }
                        setState(() {});
                      },
                    ),

                    // 🔔 서비스 알림 (카드 스타일 + 아이폰 스위치)
                    _SwitchCard(
                      title: 'notifications'.tr(),
                      value: _notificationEnabled,
                      onChanged: _toggleNotification,
                    ),

                    // 📢 마케팅 정보 수신 (카드 스타일 + 아이폰 스위치)
                    _SwitchCard(
                      title: 'marketing_info'.tr(),
                      value: _marketingEnabled,
                      onChanged: _toggleMarketing,
                    ),

                    // 🚀 온보딩 다시보기 (카드 스타일)
                    _SettingCard(
                      title: 'view_onboarding'.tr(),
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('onboarding_done', false);
                        if (!mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const OnboardingPage(),
                          ),
                          (route) => false,
                        );
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// =======================================================
// 하단 공통 위젯들 (디자인 싹 바꿈)
// =======================================================

// ✅ 3단계: 메뉴 카드 디자인 위젯
class _SettingCard extends StatelessWidget {
  final String title;
  final String? trailingText;
  final VoidCallback onTap;
  final Color? iconColor; // 👈 여기에 '색깔 변수'를 추가했어!

  const _SettingCard({
    required this.title,
    required this.onTap,
    this.trailingText,
    this.iconColor, // 👈 생성자에도 추가!
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Theme(
        // ❶ ListTile의 클릭 효과를 여기서 죽입니다.
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent, // 물결 제거
          highlightColor: Colors.transparent, // 하이라이트 제거
          hoverColor: Colors.transparent, // 호버 제거
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(25, 10, 21, 10),
          title: Text(
            title,
            style: AppTextStyles.body.copyWith(
              fontSize: 15,
              color: AppColors.textColor01,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailingText != null)
                Text(
                  trailingText!,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.travelingBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(width: 10),
              // ✅ SvgPicture에 '마법 가루(ColorFilter)'를 뿌려주는 거야!
              SvgPicture.asset(
                'assets/icons/ico_user_more.svg',
                color: iconColor,
              ),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

// ✅ 4단계: 스위치 카드 디자인 위젯
class _SwitchCard extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchCard({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(25, 10, 18, 10),
        title: Text(
          title,
          style: AppTextStyles.body.copyWith(
            fontSize: 15,
            color: AppColors.textColor01,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Transform.scale(
          scale: 0.9, // ✅ 스위치 크기 살짝 줄임
          child: CupertinoSwitch(
            value: value,
            activeColor: AppColors.travelingBlue,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
