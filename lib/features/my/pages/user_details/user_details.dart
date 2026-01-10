import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart'; // 추가

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

import 'package:travel_memoir/features/my/pages/user_details/my_profile_page.dart';
import 'package:travel_memoir/features/my/pages/user_details/account_management_page.dart';
import 'package:travel_memoir/features/my/pages/user_details/pay_management_page.dart';

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
        title: Text('user_detail_title'.tr()), // ✅ 번역 적용
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const _Divider(),
          _SettingTile(
            title: 'login_info'.tr(), // ✅ 번역 적용
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyProfilePage()),
              );
            },
          ),
          const _Divider(),
          _SettingTile(
            title: 'account_management'.tr(), // ✅ 번역 적용
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AccountManagementPage(),
                ),
              );
            },
          ),
          const _Divider(),
          _SettingTile(
            title: 'payment_management'.tr(), // ✅ 번역 적용
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PayManagementPage()),
              );
            },
          ),
          const _Divider(),
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
        'logout'.tr(), // ✅ 번역 적용
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
  const _Divider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Divider(height: 1),
    );
  }
}
