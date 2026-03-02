import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart'; // 추가
import 'package:travel_memoir/core/constants/app_colors.dart';

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
          backgroundColor: const Color(0xFFF6F6F6),
          body: SafeArea(
            bottom: false, // 👈 하단은 수동으로 처리
            child: Column(
              children: [
                // ✅ 커스텀 타이틀 바
                Padding(
                  padding: const EdgeInsets.fromLTRB(27, 18, 27, 0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          'account_management'.tr(),
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // ✅ 흰색 카드 (Expanded 제거 → 내용 크기만큼만)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(27, 0, 27, 27),
                    child: Container(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 30,
                          horizontal: 30,
                        ),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'delete_account'.tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textColor01,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'delete_account_warning'.tr(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w300,
                                color: Color(0xFF858585),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 5,
                              ), // 👈 왼쪽에 5px 여백 추가
                              child: Text(
                                'delete_account_data_list'.tr(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textColor01,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ), // 👈 Expanded 닫는 괄호 추가
                ),

                // ✅ 하단 삭제 버튼 (홈 인디케이터까지 꽉 채움)
                GestureDetector(
                  onTap: _deleting ? null : () => _deleteAccount(context),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 60,
                        color: _deleting ? Colors.grey : Colors.red,
                        child: Center(
                          child: _deleting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'delete_account'.tr(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        height: MediaQuery.of(context).padding.bottom,
                        color: _deleting ? Colors.grey : Colors.red,
                      ),
                    ],
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
