import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:travel_memoir/features/my/pages/profile_edit_page.dart';
import 'package:travel_memoir/features/my/pages/my_travels/my_travel_summary_page.dart';
import 'package:travel_memoir/features/my/pages/settings/my_settings_page.dart';
import 'package:travel_memoir/features/my/pages/supports/my_support_page.dart';
import 'package:travel_memoir/features/my/pages/user_details/user_details.dart';
import 'package:travel_memoir/features/my/pages/shop/coin_shop_page.dart';
import 'package:travel_memoir/features/my/pages/sticker/my_sticker_page.dart';
import 'package:travel_memoir/features/my/pages/map_management/map_management_page.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  // ✅ [수정] 클래스 변수에서 currentUser!.id 제거 (로그아웃 시 Null 에러 방지)

  Future<Map<String, dynamic>> _getProfileData() async {
    try {
      debugPrint("🔍 [MyPage] 데이터 로딩 시퀀스 시작...");

      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        debugPrint("⚠️ [MyPage] 세션 없음: 로그아웃 상태입니다.");
        return {'profile': null, 'completedTravels': [], 'travelCount': 0};
      }

      final userId = user.id;
      debugPrint("✅ [MyPage] 로그인 사용자 확인 (UID: $userId)");

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

      debugPrint("✅ [MyPage] 데이터 수신 완료");

      return {
        'profile': results[0],
        'completedTravels': results[1] ?? [],
        'travelCount': (results[1] as List?)?.length ?? 0,
      };
    } catch (e, stacktrace) {
      debugPrint("❌ [MyPage] 데이터 로드 중 에러 발생: $e");
      debugPrint(stacktrace.toString());
      rethrow;
    }
  }

  // ⬢ 스티커 팝업 호출
  void _showStickerPopup(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'StickerPopup',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.75,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const MyStickerPage(),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: child,
        );
      },
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
            // 로그아웃 중이거나 데이터가 없을 때의 예외 처리
            if (!snapshot.hasData || snapshot.data!['profile'] == null) {
              return Center(child: Text("error_loading_data".tr()));
            }

            final profile = snapshot.data!['profile'];
            final travelCount = snapshot.data!['travelCount'] as int;
            final nickname = profile['nickname'] ?? 'default_nickname'.tr();
            final imageUrl = profile['profile_image_url'];
            final badge = _getBadge(travelCount);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ [수정] 이미지와 닉네임 영역 전체를 클릭 가능하게 변경
                  GestureDetector(
                    onTap: () async {
                      debugPrint("📸 [MyPage] ProfileEditPage로 이동");
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
                              const SizedBox(height: 16),
                              // 여권 버튼 (이 버튼은 별도 이벤트가 있으므로 GestureDetector 밖으로 빼거나 처리 필요)
                              // 여기서는 Row 안에 있으므로 클릭 시 프로필 수정으로 가되,
                              // 아래의 GestureDetector가 중첩되지 않게 주의해야 합니다.
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
                  // 📘 여권 버튼 (별도 터치 영역)
                  GestureDetector(
                    onTap: () => _showStickerPopup(context),
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profile['email'] ?? '',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 10),

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
                          if (mounted) setState(() {}); // ✅ [수정] mounted 체크 추가
                        },
                      ),
                      _MenuTile(
                        title: 'map_settings'.tr(),
                        icon: Icons.map_outlined,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MapManagementPage(),
                            ),
                          );
                        },
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
                          if (mounted) setState(() {}); // ✅ [수정] mounted 체크 추가
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

// ⬢ 육각형 클리퍼
class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    path.moveTo(w * 0.5, 0);
    path.lineTo(w, h * 0.25);
    path.lineTo(w, h * 0.75);
    path.lineTo(w * 0.5, h);
    path.lineTo(0, h * 0.75);
    path.lineTo(0, h * 0.25);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
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
