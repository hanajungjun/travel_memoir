import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

import 'package:travel_memoir/features/my/pages/user_details/my_profile_page.dart';
import 'package:travel_memoir/features/my/pages/user_details/account_management_page.dart';
import 'package:travel_memoir/features/my/pages/user_details/pay_management_page.dart';

import 'package:flutter_svg/flutter_svg.dart'; // 👈 이 한 줄을 맨 위에 추가!

class MyUserDetailPage extends StatelessWidget {
  const MyUserDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 배경색을 연회색으로 변경
      backgroundColor: const Color(0xFFF6F6F6),
      // 기존 AppBar 제거 후 SafeArea와 Stack으로 커스텀 상단바 구현
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(27, 18, 27, 27),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ❶ 커스텀 상단바 (제목 중앙 정렬)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      'user_detail_title'.tr(), // ✅ 번역 적용
                      style: AppTextStyles.pageTitle.copyWith(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textColor01,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              // ❷ 메뉴 카드 리스트 (로직은 그대로 유지)
              _SettingTile(
                title: 'login_info'.tr(), // ✅ 번역 적용
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyProfilePage()),
                  );
                },
              ),
              _SettingTile(
                title: 'account_management'.tr(), // ✅ 번역 적용
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AccountManagementPage(),
                    ),
                  );
                },
              ),
              _SettingTile(
                title: 'payment_management'.tr(), // ✅ 번역 적용
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PayManagementPage(),
                    ),
                  );
                },
              ),
              _LogoutTile(
                onTap: () async {
                  try {
                    final info = await Purchases.getCustomerInfo();
                    // anonymous 유저가 아닐 때만 logOut 호출
                    if (!info.originalAppUserId.startsWith('\$RCAnonymousID')) {
                      await Purchases.logOut();
                    }
                  } catch (e) {
                    debugPrint('RevenueCat logOut 스킵: $e');
                  }

                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =======================================================
// 공통 위젯 (디자인만 카드 스타일로 수정)
// =======================================================

class _SettingTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _SettingTile({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Container(
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
        child: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent, // 물결 효과 투명하게
            highlightColor: Colors.transparent, // 탭 배경색 투명하게
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(25, 10, 21, 10),
            title: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textColor01,
              ),
            ),
            // 원래 있던 Icons.chevron_right 코드를 지우고 이걸 넣으세요!
            trailing: SvgPicture.asset('assets/icons/ico_user_more.svg'),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Container(
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
        child: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent, // 물결 효과 투명하게
            highlightColor: Colors.transparent, // 탭 배경색 투명하게
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(25, 10, 21, 10),
            leading: SvgPicture.asset('assets/icons/ico_user_logout.svg'),
            horizontalTitleGap: 0,
            title: Text(
              'logout'.tr(), // ✅ 번역 적용
              style: AppTextStyles.body.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

// 기존 리스트 형태에서 카드로 변경되었으므로 구분선 위젯은 사용하지 않지만 로직 보존을 위해 남겨둠
class _Divider extends StatelessWidget {
  const _Divider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Divider(height: 1),
    );
  }
}
