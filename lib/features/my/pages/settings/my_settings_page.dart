import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/screens/onboarding_screen.dart';

class MySettingsPage extends StatefulWidget {
  const MySettingsPage({super.key});

  @override
  State<MySettingsPage> createState() => _MySettingsPageState();
}

class _MySettingsPageState extends State<MySettingsPage> {
  bool _notificationEnabled = true;
  bool _marketingEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationEnabled = prefs.getBool('notification_enabled') ?? true;
      _marketingEnabled = prefs.getBool('marketing_enabled') ?? false;
    });
  }

  // 🔔 알림 토글 로직 (즉시 반영 + 에러 방지)
  Future<void> _toggleNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _notificationEnabled = value);
    await prefs.setBool('notification_enabled', value);

    try {
      // 1. 즉시 포그라운드 알림 설정 변경 (앱 안 꺼도 바로 적용됨) ⭐
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: value,
            badge: value,
            sound: value,
          );

      // 2. 토픽 구독/해제
      if (value) {
        await FirebaseMessaging.instance.subscribeToTopic('all_users');
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic('all_users');
      }
    } catch (e) {
      debugPrint("FCM 알림 설정 중 오류: $e");
      // 에러가 나도 스위치 상태는 유지되도록 함
    }
  }

  // 📢 마케팅 알림 토글 로직
  Future<void> _toggleMarketing(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _marketingEnabled = value);
    await prefs.setBool('marketing_enabled', value);

    try {
      if (value) {
        await FirebaseMessaging.instance.subscribeToTopic('marketing');
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic('marketing');
      }
    } catch (e) {
      debugPrint("FCM 마케팅 설정 중 오류: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('settings'.tr()), // ✅ 기존 번역 유지
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // 🌍 언어 변경 (유저님 기존 로직 100% 동일)
            _SettingTile(
              title: 'language'.tr(),
              trailingText: context.locale.languageCode == 'ko'
                  ? '한국어'
                  : 'English',
              onTap: () {
                if (context.locale.languageCode == 'ko') {
                  context.setLocale(const Locale('en'));
                } else {
                  context.setLocale(const Locale('ko'));
                }
                setState(() {});
              },
            ),
            _Divider(),

            // 🔔 알림 설정 (FCM 연동으로 업그레이드)
            _SwitchTile(
              title: 'notifications'.tr(),
              value: _notificationEnabled,
              onChanged: _toggleNotification,
            ),
            _Divider(),

            // 📢 마케팅 설정 (FCM 연동으로 업그레이드)
            _SwitchTile(
              title: 'marketing_info'.tr(),
              value: _marketingEnabled,
              onChanged: _toggleMarketing,
            ),
            _Divider(),

            // 🚀 온보딩 다시보기 (유저님 기존 로직 100% 동일)
            _SettingTile(
              title: 'view_onboarding'.tr(),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('onboarding_done', false);
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const OnboardingPage()),
                  (route) => false,
                );
              },
            ),
            _Divider(),

            // 📊 데이터 설정
            _SettingTile(
              title: 'data_settings'.tr(),
              onTap: () {
                // TODO: 데이터 설정 페이지
              },
            ),
            _Divider(),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// 하단 공통 위젯들 (유저님 코드 그대로 유지)
// =======================================================

class _SettingTile extends StatelessWidget {
  final String title;
  final String? trailingText;
  final VoidCallback onTap;

  const _SettingTile({
    required this.title,
    required this.onTap,
    this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(title, style: AppTextStyles.body),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText!,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(title, style: AppTextStyles.body),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Divider(height: 1, thickness: 0.5),
    );
  }
}
