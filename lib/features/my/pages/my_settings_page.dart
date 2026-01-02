import 'package:flutter/material.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class MySettingsPage extends StatelessWidget {
  const MySettingsPage({super.key});

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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // =========================
            // 지역
            // =========================
            _SectionTitle('지역'),
            _Divider(),

            _SettingTile(
              title: '통화',
              subtitle: '대한민국 원',
              onTap: () {
                // TODO: 통화 설정
              },
            ),
            _Divider(),

            _SettingTile(
              title: '국가 또는 지역',
              subtitle: '대한민국',
              onTap: () {
                // TODO: 국가/지역 설정
              },
            ),

            const SizedBox(height: 32),

            // =========================
            // 기타
            // =========================
            _SectionTitle('기타'),
            _Divider(),

            _SettingTile(
              title: '마케팅 옵션',
              onTap: () {
                // TODO: 마케팅 옵션
              },
            ),
            _Divider(),

            _SettingTile(
              title: '데이터 설정',
              onTap: () {
                // TODO: 데이터 설정
              },
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// 공통 위젯들
// =======================================================

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(text, style: AppTextStyles.pageTitle.copyWith(fontSize: 22)),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingTile({required this.title, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(title, style: AppTextStyles.body),
      subtitle: subtitle != null
          ? Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(subtitle!, style: AppTextStyles.caption),
            )
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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
