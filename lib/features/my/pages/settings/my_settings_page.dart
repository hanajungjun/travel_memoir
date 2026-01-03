import 'package:flutter/material.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

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
        title: const Text('설정'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),

          // =========================
          // 언어
          // =========================
          _SettingTile(
            title: '언어',
            trailingText: '한국어',
            onTap: () {
              // TODO: 언어 선택 페이지 (나중)
            },
          ),
          _Divider(),

          // =========================
          // 알림
          // =========================
          _SwitchTile(
            title: '알림',
            value: _notificationEnabled,
            onChanged: (value) {
              setState(() {
                _notificationEnabled = value;
              });
              // TODO: 알림 설정 저장 (Supabase)
            },
          ),
          _Divider(),

          // =========================
          // 마케팅 정보 수신
          // =========================
          _SwitchTile(
            title: '마케팅 정보 수신',
            value: _marketingEnabled,
            onChanged: (value) {
              setState(() {
                _marketingEnabled = value;
              });
              // TODO: 마케팅 수신 여부 저장
            },
          ),
          _Divider(),

          // =========================
          // 데이터 설정
          // =========================
          _SettingTile(
            title: '데이터 설정',
            onTap: () {
              // TODO: 데이터 설정 페이지
            },
          ),
          _Divider(),
        ],
      ),
    );
  }
}

// =======================================================
// 공통 위젯
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
          const Icon(Icons.chevron_right),
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
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Divider(height: 1),
    );
  }
}
