import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/features/auth/login_page.dart';
import 'package:travel_memoir/features/my/pages/profile_edit_page.dart';
import 'package:travel_memoir/features/my/pages/my_travels/my_travel_summary_page.dart';
import 'package:travel_memoir/features/my/pages/settings/my_settings_page.dart';
import 'package:travel_memoir/features/my/pages/supports/my_support_page.dart';
import 'package:travel_memoir/features/my/pages/user_details/user_details.dart';

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
    _future = _fetchMyProfileWithStats();
  }

  // 📡 프로필 정보와 여행 횟수를 한 번에 가져오기
  Future<Map<String, dynamic>> _fetchMyProfileWithStats() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser!;

    // 1. 유저 프로필 정보 가져오기
    final profile = await supabase
        .from('users')
        .select()
        .eq('auth_uid', user.id)
        .single();

    // 2. 완료된 여행 데이터 리스트 가져오기 (count 파라미터 대신 길이를 활용)
    final List<dynamic> travels = await supabase
        .from('travels')
        .select('id') // id만 가져오는 게 메모리에 훨씬 이득입니다!
        .eq('user_id', user.id)
        .eq('is_completed', true);

    // 가져온 리스트의 길이가 곧 여행 횟수입니다.
    final travelCount = travels.length;

    return {'profile': profile, 'travelCount': travelCount};
  }

  // 🎖️ 여행 횟수에 따른 칭호 부여 로직
  Map<String, dynamic> _getBadge(int count) {
    if (count >= 16) {
      return {'title': '지구 정복자 🌍', 'color': Colors.deepPurple};
    } else if (count >= 6) {
      return {'title': '프로 방랑객 🎒', 'color': Colors.blueAccent};
    } else if (count >= 1) {
      return {'title': '새내기 여행자 🌱', 'color': Colors.green};
    } else {
      return {'title': '모험 준비 중 🚀', 'color': Colors.grey};
    }
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

            final data = snapshot.data!;
            final profile = data['profile'];
            final travelCount = data['travelCount'] as int;
            final badge = _getBadge(travelCount);

            final imageUrl = profile['profile_image_url'];
            final nickname = profile['nickname'] ?? '여행자';

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // =========================
                  // 👤 상단 프로필 (닉네임 + 칭호)
                  // =========================
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  nickname,
                                  style: AppTextStyles.pageTitle.copyWith(
                                    fontSize: 24,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // 칭호 뱃지
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badge['color'].withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: badge['color'].withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    badge['title'],
                                    style: TextStyle(
                                      color: badge['color'],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              profile['email'] ?? '',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
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
                              _future = _fetchMyProfileWithStats();
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

                  const SizedBox(height: 32),

                  Text('계정 관리', style: AppTextStyles.sectionTitle),
                  const SizedBox(height: 16),

                  // =========================
                  // 🧩 2x2 타일 메뉴 (그대로)
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

// 🔹 타일 위젯 (그대로)
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
