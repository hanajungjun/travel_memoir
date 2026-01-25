import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:travel_memoir/features/my/pages/profile_edit_page.dart';
import 'package:travel_memoir/features/my/pages/my_travels/my_travel_summary_page.dart';
import 'package:travel_memoir/features/my/pages/settings/my_settings_page.dart';
import 'package:travel_memoir/features/my/pages/supports/my_support_page.dart';
import 'package:travel_memoir/features/my/pages/user_details/user_details.dart';
import 'package:travel_memoir/features/my/pages/shop/coin_shop_page.dart';
import 'package:travel_memoir/features/my/pages/sticker/passport_open_dialog.dart';
import 'package:travel_memoir/features/my/pages/map_management/map_management_page.dart';

import 'package:travel_memoir/core/utils/travel_utils.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  Future<Map<String, dynamic>> _getProfileData() async {
    try {
      debugPrint("🔍 [MyPage] 데이터 로딩 시퀀스 시작...");
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        return {'profile': null, 'completedTravels': [], 'travelCount': 0};
      }

      final userId = user.id;
      final userFuture = Supabase.instance.client
          .from('users')
          .select()
          .eq('auth_uid', userId)
          .maybeSingle();

      final travelFuture = Supabase.instance.client
          .from('travels')
          .select('*')
          .eq('user_id', userId)
          .eq('is_completed', true)
          .order('created_at', ascending: false);

      final results = await Future.wait([userFuture, travelFuture]);

      return {
        'profile': results[0],
        'completedTravels': results[1] ?? [],
        'travelCount': (results[1] as List?)?.length ?? 0,
      };
    } catch (e) {
      debugPrint("❌ [MyPage] 데이터 로드 중 에러 발생: $e");
      rethrow;
    }
  }

  // ⬢ 프리미엄 체크 및 여권 팝업 제어
  void _handlePassportTap(bool isPremium) {
    if (isPremium) {
      // ✅ 프리미엄이면 여권 열어줌
      _showStickerPopup(context);
    } else {
      // ❌ 일반 유저면 알림 후 상점으로 유도
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('premium_only_title'.tr()),
          content: Text('premium_passport_desc'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('close'.tr()),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // 알림창 닫고
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CoinShopPage()),
                ).then((_) => setState(() {})); // 돌아오면 상태 갱신
              },
              child: Text('go_to_shop'.tr()),
            ),
          ],
        ),
      );
    }
  }

  void _showStickerPopup(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'PassportPopup',
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return const PassportOpeningDialog();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _getProfileData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!['profile'] == null) {
              return Center(child: Text("error_loading_data".tr()));
            }

            final profile = snapshot.data!['profile'];
            final travelCount = snapshot.data!['travelCount'] as int;
            final nickname = profile['nickname'] ?? 'default_nickname'.tr();
            final imageUrl = profile['profile_image_url'];
            final badge = getBadge(travelCount);

            // 💎 프리미엄 여부 확인
            final bool isPremium = profile['is_premium'] ?? false;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileEditPage(),
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                    child: Row(
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
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildBadge(badge),
                                  if (isPremium) ...[
                                    const SizedBox(width: 6),
                                    _buildPremiumMark(), // 위에서 만든 멋진 마크
                                    // const Icon(
                                    //   Icons.stars_rounded,
                                    //   color: Colors.amber,
                                    //   size: 20,
                                    // ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: Colors.grey.shade100,
                          backgroundImage: imageUrl != null
                              ? NetworkImage(imageUrl)
                              : null,
                          child: imageUrl == null
                              ? const Icon(
                                  Icons.person,
                                  size: 38,
                                  color: Colors.grey,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 📘 여권 버튼 (프리미엄 전용 로직 적용)
                  GestureDetector(
                    onTap: () => _handlePassportTap(isPremium),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A3D2F),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.menu_book,
                            color: Color(0xFFE5C100),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'passport_label'.tr(),
                            style: const TextStyle(
                              color: Color(0xFFE5C100),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          if (!isPremium) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.lock_outline_rounded,
                              color: Color(0xFFE5C100),
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Text(
                    profile['email'] ?? '',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 24),

                  GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _MenuTile(
                        title: 'my_travels'.tr(),
                        icon: Icons.public,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyTravelSummaryPage(),
                          ),
                        ),
                      ),
                      _MenuTile(
                        title: 'coin_shop'.tr(),
                        icon: Icons.shopping_bag_outlined,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CoinShopPage(),
                            ),
                          );
                          if (mounted) setState(() {});
                        },
                      ),
                      _MenuTile(
                        title: 'map_settings'.tr(),
                        icon: Icons.map_outlined,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MapManagementPage(),
                          ),
                        ),
                      ),
                      _MenuTile(
                        title: 'user_detail_title'.tr(),
                        icon: Icons.manage_accounts_outlined,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyUserDetailPage(),
                            ),
                          );
                          if (mounted) setState(() {});
                        },
                      ),
                      _MenuTile(
                        title: 'support'.tr(),
                        icon: Icons.menu_book_outlined,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MySupportPage(),
                          ),
                        ),
                      ),
                      _MenuTile(
                        title: 'settings'.tr(),
                        icon: Icons.settings_outlined,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MySettingsPage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // 닉네임 옆에 들어갈 프리미엄 엠블럼
  Widget _buildPremiumMark() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        // 1. 더 화려한 프리미엄 그라데이션
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFBC02D), // 진한 황금색
            Color(0xFFFFEB3B), // 밝은 노란색
            Color(0xFFFBC02D), // 다시 진한색 (광택 효과)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
        // 2. 은은한 후광(Glow) 효과 추가
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.5),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 에러 방지를 위해 여기 있던 const를 리스트에서 제거했습니다.
          const Icon(
            Icons.workspace_premium,
            color: Color(0xFF795548), // 황금색과 잘 어울리는 갈색톤 아이콘
            size: 14,
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(Map<String, dynamic> badge) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badge['color'].withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badge['color'].withOpacity(0.3)),
      ),
      child: Text(
        (badge['title_key'] as String).tr(),
        style: TextStyle(
          color: badge['color'],
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}

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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF0F0F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 32, color: Colors.blue.shade700),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
