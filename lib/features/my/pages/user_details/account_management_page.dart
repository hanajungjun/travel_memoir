import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/features/auth/login_page.dart';

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

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('계정 삭제'),
        content: const Text(
          '계정을 삭제하면 모든 데이터가 영구적으로 삭제되며\n'
          '되돌릴 수 없습니다.\n\n'
          '정말 삭제하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _deleting = true);

    try {
      // 🔥 Edge Function 호출
      await supabase.functions.invoke('delete-user');

      // 🔥 세션 정리
      await supabase.auth.signOut();

      if (!mounted) return;

      // 🔥 즉시 로그인 화면으로 리셋
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _deleting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('계정 삭제 중 오류가 발생했습니다.\n$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('계정 관리'),
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

                Text('계정 삭제', style: AppTextStyles.pageTitle),
                const SizedBox(height: 16),

                Text('계정을 삭제하면 아래 데이터가 모두 삭제됩니다.', style: AppTextStyles.body),
                const SizedBox(height: 8),
                Text(
                  '• 여행 기록\n'
                  '• 이미지 및 다이어리\n'
                  '• 결제 정보\n'
                  '• 계정 정보',
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
                    child: const Text(
                      '계정 삭제',
                      style: TextStyle(
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

        // =========================
        // 🔒 탈퇴 중 로딩 오버레이
        // =========================
        // =========================
        // 🔒 탈퇴 중 로딩 오버레이
        // =========================
        if (_deleting)
          Container(
            color: Colors.black.withOpacity(0.4),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline, size: 48, color: Colors.white70),
                  const SizedBox(height: 16),
                  Text(
                    '마지막 정리를 하고 있어요',
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
