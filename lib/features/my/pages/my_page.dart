import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/features/auth/login_page.dart';
import 'package:travel_memoir/features/my/pages/profile_edit_page.dart';
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

  Future<void> _openEditProfile() async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileEditPage()),
    );

    if (updated == true) {
      setState(() {
        _future = _fetchMyProfile();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text('마이페이지', style: AppTextStyles.pageTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              Icons.notifications_none,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = snapshot.data!;
          final nickname = profile['nickname'] ?? '여행자';
          final email = profile['email'] ?? '';
          final bio = profile['bio'] ?? '';
          final imageUrl = profile['profile_image_url'];

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // ======================
              // 👤 프로필 영역
              // ======================
              Row(
                children: [
                  CircleAvatar(
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nickname, style: AppTextStyles.pageTitle),
                        if (bio.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(bio, style: AppTextStyles.bodyMuted),
                        ],
                        const SizedBox(height: 4),
                        Text(email, style: AppTextStyles.bodyMuted),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ======================
              // 📊 요약 정보
              // ======================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  _StatItem(title: '포인트', value: '0'),
                  _StatItem(title: '쿠폰', value: '0'),
                  _StatItem(title: '관심 여행', value: '0'),
                ],
              ),

              const SizedBox(height: 28),

              // ======================
              // ✏️ 프로필 수정
              // ======================
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
                  onPressed: _openEditProfile,
                  child: Text('프로필 수정', style: AppTextStyles.button),
                ),
              ),

              const SizedBox(height: 32),

              // ======================
              // 📂 메뉴 리스트
              // ======================
              const _MenuItem(icon: Icons.bookmark_border, title: '저장됨'),
              const _MenuItem(icon: Icons.mail_outline, title: '메시지'),
              const _MenuItem(icon: Icons.calendar_today, title: '내 예약'),
              const _MenuItem(icon: Icons.person_outline, title: '회원 정보 수정'),
              const _MenuItem(icon: Icons.group_outlined, title: '여행자 정보 관리'),
              const _MenuItem(
                icon: Icons.notifications_outlined,
                title: '알림 설정',
              ),
              const _MenuItem(icon: Icons.help_outline, title: '공지사항 및 FAQ'),
              const _MenuItem(icon: Icons.support_agent, title: '문의하기'),
              const _MenuItem(icon: Icons.description_outlined, title: '이용 약관'),

              const SizedBox(height: 36),

              // ======================
              // 🔴 로그아웃
              // ======================
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.textPrimary,
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
                  child: Text('로그아웃', style: AppTextStyles.button),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ======================
// 🔹 통계 아이템
// ======================
class _StatItem extends StatelessWidget {
  final String title;
  final String value;

  const _StatItem({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.pageTitle),
        const SizedBox(height: 4),
        Text(title, style: AppTextStyles.bodyMuted),
      ],
    );
  }
}

// ======================
// 🔹 메뉴 아이템
// ======================
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;

  const _MenuItem({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title, style: AppTextStyles.body),
      trailing: Icon(Icons.chevron_right, color: AppColors.textDisabled),
      onTap: () {},
    );
  }
}
