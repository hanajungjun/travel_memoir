import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/features/my/pages/map_management/map_management_page.dart';
import 'package:travel_memoir/core/widgets/popup/app_dialogs.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'domestic_travel_date_page.dart';
import 'overseas_travel_date_page.dart';
import 'us_travel_date_page.dart';

class TravelTypeSelectPage extends StatefulWidget {
  const TravelTypeSelectPage({super.key});

  @override
  State<TravelTypeSelectPage> createState() => _TravelTypeSelectPageState();
}

class _TravelTypeSelectPageState extends State<TravelTypeSelectPage> {
  bool _loading = true;
  bool _hasUsaAccess = false;

  @override
  void initState() {
    super.initState();
    _checkMapAccess();
  }

  /// ✅ 사용자의 미국 지도 구매 여부 확인
  Future<void> _checkMapAccess() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final res = await Supabase.instance.client
          .from('users')
          .select('active_maps')
          .eq('auth_uid', user.id)
          .maybeSingle();

      if (res != null && res['active_maps'] != null) {
        final List activeMaps = res['active_maps'] as List;
        if (mounted) {
          setState(() {
            // 'us'가 포함되어 있는지 확인
            _hasUsaAccess = activeMaps.contains('us');
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Access Check Error: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ✅ 구매 유도 팝업 (상점 연결 로직 추가)
  // ✅ [수정 완료] AppDialogs.showAction 적용
  void _showPurchaseDialog() {
    AppDialogs.showAction(
      context: context,
      title: 'purchase_title',
      message: 'purchase_us_map_msg',
      actionLabel: 'go_to_management',
      // actionColor는 AppDialogs의 기본값(amber 또는 blue)을 사용합니다.
      onAction: () {
        // 🎯 관리 페이지 이동 및 복귀 후 권한 체크 로직
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MapManagementPage()),
        ).then((_) => _checkMapAccess());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(27, 76, 27, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10), // 왼쪽 패딩 추가
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 19,
                            color: Color(0xFF555759),
                          ),
                          children: [
                            TextSpan(
                              text: 'select_type_bold'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text: 'select_type_normal'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w200,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 🌍 해외 여행
                    _TravelTypeCard(
                      title: 'overseas_travel_comma'.tr(),
                      description: 'overseas_description'.tr(),
                      iconPath: 'assets/icons/ico_Abroad.svg',
                      iconColor: const Color(0xFF6C5CE7),
                      onTap: () => _navigateToPage(
                        context,
                        const OverseasTravelDatePage(),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // 🇰🇷 국내 여행
                    _TravelTypeCard(
                      title: 'domestic_travel_comma'.tr(),
                      description: 'domestic_description'.tr(),
                      iconPath: 'assets/icons/ico_Local.svg',
                      iconColor: const Color(0xFF3498DB),
                      onTap: () => _navigateToPage(
                        context,
                        const DomesticTravelDatePage(),
                      ),
                    ),

                    const SizedBox(height: 15),
                    // 🇺🇸 미국 여행 (비구매 시 잠금 상태)
                    _TravelTypeCard(
                      title: 'us_travel_comma'.tr(),
                      description: 'us_description'.tr(),
                      iconPath: 'assets/icons/ico_State.svg',
                      iconColor: const Color(0xFFE74C3C),
                      isLocked: !_hasUsaAccess,
                      onTap: _hasUsaAccess
                          ? () => _navigateToPage(
                              context,
                              const USTravelDatePage(),
                            )
                          : _showPurchaseDialog,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _navigateToPage(BuildContext context, Widget page) async {
    final createdTravel = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (createdTravel != null && context.mounted) {
      Navigator.pop(context, createdTravel);
    }
  }
}

class _TravelTypeCard extends StatelessWidget {
  final String title;
  final String description;
  final String iconPath;
  final Color iconColor;
  final VoidCallback onTap;
  final bool isLocked;

  const _TravelTypeCard({
    required this.title,
    required this.description,
    required this.iconPath,
    required this.iconColor,
    required this.onTap,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isLocked ? 0.5 : 1.0,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
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
          child: Row(
            children: [
              // ✅ BoxDecoration(Shape) 제거 후 아이콘만 배치
              Padding(
                padding: const EdgeInsets.only(
                  bottom: 20,
                ), // 원하는 만큼 숫자 조절 (예: 4~8)
                child: SvgPicture.asset(
                  iconPath,
                  width: 26,
                  height: 26,
                  color: isLocked ? Color(0xFFCACBCC) : iconColor,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ 이미지에서 오류나던 RichText를 깔끔한 Text 위젯으로 교체
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isLocked ? 'unlock_required'.tr() : description,
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 14,
                        fontWeight: FontWeight.w200,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
