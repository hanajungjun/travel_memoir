import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
// ✅ [추가] RevenueCat 패키지 임포트
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:travel_memoir/features/auth/login_page.dart';
import 'package:travel_memoir/features/my/pages/profile_edit_page.dart';
import 'package:travel_memoir/features/my/pages/my_travels/my_travel_summary_page.dart';
import 'package:travel_memoir/features/my/pages/settings/my_settings_page.dart';
import 'package:travel_memoir/features/my/pages/supports/my_support_page.dart';
import 'package:travel_memoir/features/my/pages/user_details/user_details.dart';
import 'package:travel_memoir/features/my/pages/sticker/my_sticker_page.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:lottie/lottie.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  late Future<Map<String, dynamic>> _future;
  Locale? _lastLocale;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLocale = EasyLocalization.of(context)?.locale;

    if (_lastLocale != currentLocale) {
      _lastLocale = currentLocale;
      _future = _fetchMyProfileWithStats();
    }
  }

  Future<Map<String, dynamic>> _fetchMyProfileWithStats() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser!;

    // ⭐ [추가] RevenueCat에 현재 수파베이스 유저 아이디를 동기화
    // 이 한 줄이 있어야 '소금빵'님이 결제했을 때 누군지 알 수 있습니다.
    await Purchases.logIn(user.id);

    final profile = await supabase
        .from('users')
        .select()
        .eq('auth_uid', user.id)
        .single();

    final List<dynamic> travels = await supabase
        .from('travels')
        .select('id')
        .eq('user_id', user.id)
        .eq('is_completed', true);

    final travelCount = travels.length;

    return {'profile': profile, 'travelCount': travelCount};
  }

  // ✅ 구독 상태 확인 로직
  bool _checkPremium(Map<String, dynamic> profile) {
    final bool isPremium = profile['is_premium'] ?? false;
    final String? premiumUntil = profile['premium_until'];

    if (!isPremium) return false;
    if (premiumUntil == null) return false;

    try {
      final DateTime untilDate = DateTime.parse(premiumUntil);
      return untilDate.isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  // ✅ 프리미엄 전용 팝업 알림
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              // TODO: 나중에 만들 결제 페이지로 이동
            },
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
    if (count >= 16) {
      return {'title_key': 'badge_earth_conqueror', 'color': Colors.deepPurple};
    } else if (count >= 6) {
      return {'title_key': 'badge_pro_wanderer', 'color': Colors.blueAccent};
    } else if (count >= 1) {
      return {'title_key': 'badge_newbie_traveler', 'color': Colors.green};
    } else {
      return {'title_key': 'badge_preparing_adventure', 'color': Colors.grey};
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
            final nickname = profile['nickname'] ?? 'default_nickname'.tr();

            final bool isSubscribed = _checkPremium(profile);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 프로필 섹션
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
                                    (badge['title_key'] as String).tr(),
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
                          if (updated == true)
                            setState(() {
                              _future = _fetchMyProfileWithStats();
                            });
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

                  // 메뉴 그리드
                  GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _MenuTile(
                        title: 'user_detail_title'.tr(),
                        icon: Icons.manage_accounts_outlined,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyUserDetailPage(),
                          ),
                        ),
                      ),
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
                        title: 'my_stickers'.tr(),
                        icon: Icons.portrait_rounded,
                        isLocked: !isSubscribed,
                        onTap: () {
                          if (isSubscribed) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MyStickerPage(),
                              ),
                            );
                          } else {
                            _showPremiumAlert(context);
                          }
                        },
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
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Lottie.asset(
                            'assets/lottie/Happy New Year Cat Jumping.json',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
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
                      child: Text('logout'.tr(), style: AppTextStyles.body),
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isLocked
              ? AppColors.lightSurface.withOpacity(0.5)
              : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  size: 40,
                  color: isLocked
                      ? AppColors.textDisabled
                      : AppColors.textPrimary,
                ),
                if (isLocked)
                  const Icon(Icons.lock_outline, size: 20, color: Colors.amber),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
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
