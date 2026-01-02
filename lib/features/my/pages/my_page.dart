import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/features/auth/login_page.dart';
import 'package:travel_memoir/features/my/pages/profile_edit_page.dart';
import 'package:travel_memoir/features/my/pages/my_travel_summary_page.dart';
import 'package:travel_memoir/features/my/pages/my_settings_page.dart';
import 'package:travel_memoir/features/my/pages/my_support_page.dart';
import 'package:travel_memoir/features/my/pages/my_profile_page.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchMyProfile();
  }

  Future<Map<String, dynamic>> _fetchMyProfile() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser!;

    return await supabase
        .from('users')
        .select()
        .eq('auth_uid', user.id)
        .single();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final profile = snapshot.data!;
            final imageUrl = profile['profile_image_url'];

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // =========================
                  // 👤 상단 프로필
                  // =========================
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '프로필',
                          style: AppTextStyles.pageTitle.copyWith(fontSize: 28),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfileEditPage(),
                            ),
                          );

                          if (updated == true) {
                            setState(() {
                              _future = _fetchMyProfile();
                            });
                          }
                        },
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.surface,
                          backgroundImage: imageUrl != null
                              ? NetworkImage(imageUrl)
                              : null,
                          child: imageUrl == null
                              ? Icon(
                                  Icons.person,
                                  size: 36,
                                  color: AppColors.textDisabled,
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  Text('계정 관리', style: AppTextStyles.sectionTitle),
                  const SizedBox(height: 16),

                  // =========================
                  // 🧩 2x2 타일 메뉴
                  // =========================
                  GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _MenuTile(
                        title: '사용자 세부 정보',
                        icon: Icons.manage_accounts_outlined,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyUserDetailPage(),
                            ),
                          );
                        },
                      ),
                      _MenuTile(
                        title: '내 여행',
                        icon: Icons.public,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyTravelSummaryPage(),
                            ),
                          );
                        },
                      ),
                      _MenuTile(
                        title: '설정',
                        icon: Icons.settings_outlined,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MySettingsPage(),
                            ),
                          );
                        },
                      ),
                      _MenuTile(
                        title: '지원',
                        icon: Icons.menu_book_outlined,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MySupportPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // =========================
                  // 🔴 로그아웃
                  // =========================
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        await Supabase.instance.client.auth.signOut();
                        if (!context.mounted) return;

                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (_) => false,
                        );
                      },
                      child: Text('로그아웃', style: AppTextStyles.body),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// =========================
// 🔹 타일 위젯
// =========================
class _MenuTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 40, color: AppColors.textPrimary),
            const Spacer(),
            Text(
              title,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
