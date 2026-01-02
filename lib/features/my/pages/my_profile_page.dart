import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';

class MyUserDetailPage extends StatelessWidget {
  const MyUserDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('사용자 세부 정보'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          _Divider(),

          _SettingTile(
            title: '로그인 정보',
            onTap: () {
              // TODO: 로그인 정보 상세
            },
          ),

          _Divider(),

          _SettingTile(
            title: '계정 관리',
            onTap: () {
              // TODO: 계정 관리 (탈퇴 등)
            },
          ),

          _Divider(),

          const SizedBox(height: 12),

          _LogoutTile(
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
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
  final VoidCallback onTap;

  const _SettingTile({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(title, style: AppTextStyles.body),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _LogoutTile extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(
        '로그아웃',
        style: AppTextStyles.body.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
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
