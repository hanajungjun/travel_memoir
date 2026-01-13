import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ Supabase 연동을 위해 추가
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
  bool _isLoading = false; // ✅ 로딩 상태 관리

  // 현재 로그인된 유저의 ID를 가져오는 getter
  String get _userId => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // 1. 설정값 불러오기 (Supabase DB를 우선으로 가져옴)
  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    try {
      // ✅ Supabase 'users' 테이블에서 설정값 조회
      final userData = await Supabase.instance.client
          .from('users')
          .select('is_push_enabled, is_marketing_enabled')
          .eq('auth_uid', _userId)
          .single();

      setState(() {
        _notificationEnabled = userData['is_push_enabled'] ?? true;
        _marketingEnabled = userData['is_marketing_enabled'] ?? false;
      });

      // 로컬 SharedPreferences도 최신화
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

  // 🔔 서비스 알림 토글 로직 (DB 업데이트 + FCM 토픽 + 로컬 저장)
  Future<void> _toggleNotification(bool value) async {
    setState(() => _notificationEnabled = value);

    try {
      // 1. Supabase DB 업데이트
      await Supabase.instance.client
          .from('users')
          .update({'is_push_enabled': value})
          .eq('auth_uid', _userId);

      // 2. FCM 설정 변경 (앱 내 알림 옵션 및 토픽 구독/해제)
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

      // 3. 로컬 SharedPreferences 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notification_enabled', value);
    } catch (e) {
      debugPrint("❌ 알림 설정 업데이트 실패: $e");
    }
  }

  // 📢 마케팅 알림 토글 로직 (DB 업데이트 + 마케팅 동의 시간 기록)
  Future<void> _toggleMarketing(bool value) async {
    setState(() => _marketingEnabled = value);

    try {
      // 1. Supabase DB 업데이트 (마케팅 동의 시간 포함)
      await Supabase.instance.client
          .from('users')
          .update({
            'is_marketing_enabled': value,
            'marketing_accepted_at': value
                ? DateTime.now().toIso8601String()
                : null,
          })
          .eq('auth_uid', _userId);

      // 2. FCM 마케팅 토픽 구독/해제
      if (value) {
        await FirebaseMessaging.instance.subscribeToTopic('marketing');
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic('marketing');
      }

      // 3. 로컬 SharedPreferences 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('marketing_enabled', value);
    } catch (e) {
      debugPrint("❌ 마케팅 설정 업데이트 실패: $e");
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
        title: Text('settings'.tr()),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // 🌍 언어 변경 섹션
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

                  // 🔔 서비스 알림 스위치 (DB 연동)
                  _SwitchTile(
                    title: 'notifications'.tr(),
                    value: _notificationEnabled,
                    onChanged: _toggleNotification,
                  ),
                  _Divider(),

                  // 📢 마케팅 정보 수신 스위치 (DB 연동)
                  _SwitchTile(
                    title: 'marketing_info'.tr(),
                    value: _marketingEnabled,
                    onChanged: _toggleMarketing,
                  ),
                  _Divider(),

                  // 🚀 온보딩 다시보기
                  _SettingTile(
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
                  _Divider(),

                  // 📊 데이터 설정
                  _SettingTile(
                    title: 'data_settings'.tr(),
                    onTap: () {
                      // TODO: 데이터 설정 페이지 연결
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
// 하단 공통 위젯들 (생략 없이 모두 포함)
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
