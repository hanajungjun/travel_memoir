import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/features/auth/login_page.dart';
import 'package:travel_memoir/features/my/pages/profile_edit_page.dart';

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
        _future = _fetchMyProfile(); // 🔥 수정 즉시 반영
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('마이페이지'),
        centerTitle: true,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.notifications_none),
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
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: imageUrl != null
                        ? NetworkImage(imageUrl)
                        : null,
                    child: imageUrl == null
                        ? const Icon(
                            Icons.person,
                            size: 36,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nickname,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (bio.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(bio, style: const TextStyle(color: Colors.grey)),
                        ],
                        const SizedBox(height: 4),
                        Text(email, style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ======================
              // 📊 요약 정보 (UI용)
              // ======================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  _StatItem(title: '포인트', value: '0'),
                  _StatItem(title: '쿠폰', value: '0'),
                  _StatItem(title: '관심 여행', value: '0'),
                ],
              ),

              const SizedBox(height: 24),

              // ======================
              // ✏️ 프로필 수정
              // ======================
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _openEditProfile,
                  child: const Text('프로필 수정'),
                ),
              ),

              const SizedBox(height: 32),

              // ======================
              // 📂 메뉴 리스트 (UI)
              // ======================
              _MenuItem(icon: Icons.bookmark_border, title: '저장됨'),
              _MenuItem(icon: Icons.mail_outline, title: '메시지'),
              _MenuItem(icon: Icons.calendar_today, title: '내 예약'),
              _MenuItem(icon: Icons.person_outline, title: '회원 정보 수정'),
              _MenuItem(icon: Icons.group_outlined, title: '여행자 정보 관리'),
              _MenuItem(icon: Icons.notifications_outlined, title: '알림 설정'),
              _MenuItem(icon: Icons.help_outline, title: '공지사항 및 FAQ'),
              _MenuItem(icon: Icons.support_agent, title: '문의하기'),
              _MenuItem(icon: Icons.description_outlined, title: '이용 약관'),

              const SizedBox(height: 32),

              // ======================
              // 🔴 로그아웃
              // ======================
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
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
                  child: const Text('로그아웃', style: TextStyle(fontSize: 16)),
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
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: Colors.grey)),
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
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }
}
