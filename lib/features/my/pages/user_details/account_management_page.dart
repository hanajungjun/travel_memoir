import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart'; // 추가

import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/features/auth/login_page.dart';
import 'package:travel_memoir/core/widgets/popup/app_toast.dart';
import 'package:travel_memoir/core/widgets/popup/app_dialogs.dart';

class AccountManagementPage extends StatefulWidget {
  const AccountManagementPage({super.key});

  @override
  State<AccountManagementPage> createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<AccountManagementPage> {
  bool _deleting = false;

  Future<void> _deleteAccount(BuildContext context) async {
    if (_deleting) return;

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // ✅ [수정 완료] AppDialogs.showConfirm 적용
    final confirm = await AppDialogs.showConfirm(
      context: context,
      title: 'delete_account',
      message: 'delete_account_confirm_message',
      confirmLabel: 'delete',
      confirmColor: Colors.red, // 👈 강조색 전달
    );

    // ✅ [수정 후 추천]
    // 사용자가 삭제를 확인(true)하지 않았다면 바로 함수를 종료시킵니다.
    if (confirm != true) return;

    // 이후 로직(_deleting = true 등)이 실질적인 '_deleteAccountLogic' 역할을 수행합니다.
    setState(() => _deleting = true);

    try {
      await supabase.functions.invoke('delete-user');
      await supabase.auth.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _deleting = false);

      AppToast.error(context, 'error_delete_account'.tr(args: [e.toString()]));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text('account_management'.tr()),
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text('delete_account'.tr(), style: AppTextStyles.pageTitle),
                const SizedBox(height: 16),
                Text('delete_account_warning'.tr(), style: AppTextStyles.body),
                const SizedBox(height: 8),
                Text(
                  'delete_account_data_list'.tr(),
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _deleting ? null : () => _deleteAccount(context),
                    child: Text(
                      'delete_account'.tr(),
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_deleting)
          Container(
            color: Colors.black.withOpacity(0.4),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.delete_outline,
                    size: 48,
                    color: Colors.white70,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'deleting_account_loading'.tr(),
                    style: AppTextStyles.body.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
