import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:travel_memoir/features/my/pages/profile_edit_page.dart';
import 'package:travel_memoir/features/my/pages/my_travels/my_travel_summary_page.dart';
import 'package:travel_memoir/features/my/pages/settings/my_settings_page.dart';
import 'package:travel_memoir/features/my/pages/supports/my_support_page.dart';
import 'package:travel_memoir/features/my/pages/user_details/user_details.dart';
import 'package:travel_memoir/features/my/pages/sticker/my_sticker_page.dart';
import 'package:travel_memoir/features/my/pages/shop/coin_shop_page.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final String _userId = Supabase.instance.client.auth.currentUser!.id;

  Future<Map<String, dynamic>> _getProfileData() async {
    final userRes = await Supabase.instance.client
        .from('users')
        .select()
        .eq('auth_uid', _userId)
        .single();

    final travelRes = await Supabase.instance.client
        .from('travels')
        .select('id')
        .eq('user_id', _userId)
        .eq('is_completed', true);

    return {'profile': userRes, 'travelCount': travelRes.length};
  }

  bool _checkPremium(Map<String, dynamic> profile) {
    final bool isPremium = profile['is_premium'] ?? false;
    final String? premiumUntil = profile['premium_until'];
    if (!isPremium || premiumUntil == null) return false;
    try {
      return DateTime.parse(premiumUntil).isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  void _showPremiumAlert(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('premium_only_title'.tr()),
        content: Text('premium_sticker_desc'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'cancel'.tr(),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(
              'view_plans'.tr(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getBadge(int count) {
    if (count >= 16)
      return {'title_key': 'badge_earth_conqueror', 'color': Colors.deepPurple};
    if (count >= 6)
      return {'title_key': 'badge_pro_wanderer', 'color': Colors.blueAccent};
    if (count >= 1)
      return {'title_key': 'badge_newbie_traveler', 'color': Colors.green};
    return {'title_key': 'badge_preparing_adventure', 'color': Colors.grey};
  }

  @override
  Widget build(BuildContext context) {
    context.locale;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _getProfileData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData) return const SizedBox.shrink();

            final profile = snapshot.data!['profile'];
            final travelCount = snapshot.data!['travelCount'] as int;

            final nickname = profile['nickname'] ?? 'default_nickname'.tr();
            final imageUrl = profile['profile_image_url'];
            final isSubscribed = _checkPremium(profile);
            final badge = _getBadge(travelCount);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 프로필 섹션
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 닉네임 (역마살)
                            Text(
                              nickname,
                              style: AppTextStyles.pageTitle.copyWith(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // ✅ 뱃지 (닉네임 아래로 이동)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: badge['color'].withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: badge['color'].withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                (badge['title_key'] as String).tr(),
                                style: TextStyle(
                                  color: badge['color'],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              profile['email'] ?? '',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 프로필 이미지
                      GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfileEditPage(),
                            ),
                          );
                          setState(() {});
                        },
                        child: CircleAvatar(
                          radius: 38,
                          backgroundColor: AppColors.surface,
                          backgroundImage: imageUrl != null
                              ? NetworkImage(imageUrl)
                              : null,
                          child: imageUrl == null
                              ? Icon(
                                  Icons.person,
                                  size: 38,
                                  color: AppColors.textDisabled,
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // 2. 메뉴 그리드
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
                          setState(() {});
                        },
                      ),
                      _MenuTile(
                        title: 'my_stickers'.tr(),
                        icon: Icons.portrait_rounded,
                        isLocked: !isSubscribed,
                        onTap: () => isSubscribed
                            ? Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MyStickerPage(),
                                ),
                              )
                            : _showPremiumAlert(context),
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
                          setState(() {});
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
}

class _MenuTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isLocked;

  const _MenuTile({
    required this.title,
    required this.icon,
    required this.onTap,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isLocked
              ? AppColors.lightSurface.withOpacity(0.5)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: isLocked ? Colors.transparent : const Color(0xFFF0F0F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: isLocked
                      ? AppColors.textDisabled
                      : AppColors.travelingBlue,
                ),
                if (isLocked)
                  const Icon(Icons.lock_outline, size: 20, color: Colors.amber),
              ],
            ),
            Text(
              title,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: isLocked
                    ? AppColors.textDisabled
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
