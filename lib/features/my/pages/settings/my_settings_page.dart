import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('settings'.tr()), // ✅ 번역 적용
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),

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

            _SwitchTile(
              title: 'notifications'.tr(), // ✅ '알림' -> 번역 적용
              value: _notificationEnabled,
              onChanged: (value) =>
                  setState(() => _notificationEnabled = value),
            ),
            _Divider(),

            _SwitchTile(
              title: 'marketing_info'.tr(), // ✅ '마케팅 정보 수신' -> 번역 적용
              value: _marketingEnabled,
              onChanged: (value) => setState(() => _marketingEnabled = value),
            ),
            _Divider(),

            _SettingTile(
              title: 'view_onboarding'.tr(), // ✅ '앱 가이드 다시보기' -> 번역 적용
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

            _SettingTile(
              title: 'data_settings'.tr(), // ✅ '데이터 설정' -> 번역 적용
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
// 공통 위젯 (아래 부분이 없어서 에러가 났던 것입니다)
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
