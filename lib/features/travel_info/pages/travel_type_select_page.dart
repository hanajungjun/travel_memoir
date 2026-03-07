import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/features/my/pages/map_management/map_management_page.dart';
import 'package:travel_memoir/core/widgets/popup/app_dialogs.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:travel_memoir/features/guide/app_guide.dart';
import 'package:travel_memoir/features/guide/tutorial_manager.dart';

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
  final GlobalKey _overseasCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _checkMapAccess();
  }

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
            _hasUsaAccess = activeMaps.contains('us');
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Access Check Error: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _showTutorialIfNecessary();
      }
    }
  }

  void _showTutorialIfNecessary() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (TutorialManager.currentStep == 3) {
        final screenWidth = MediaQuery.of(context).size.width;
        const double horizontalPadding = 27.0;
        const double cardHeight = 94.0;
        const double cardTop = 115.0; // y좌표는 항상 정확하게 나오고 있음

        // ✅ x좌표는 padding 기반으로 직접 계산
        final manualRect = Rect.fromLTWH(
          horizontalPadding,
          cardTop,
          screenWidth - horizontalPadding * 2,
          cardHeight,
        );

        AppGuide.show(
          context: context,
          targetKey: _overseasCardKey,
          message: "onboarding_title_1".tr(),
          manualRect: manualRect,
          onTargetClick: () {
            TutorialManager.markStepComplete(3);
            _navigateToPage(context, const OverseasTravelDatePage());
          },
        );
      }
    });
  }

  void _showPurchaseDialog() {
    AppDialogs.showAction(
      context: context,
      title: 'purchase_title',
      message: 'purchase_us_map_msg',
      actionLabel: 'go_to_management',
      onAction: () {
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
                      padding: const EdgeInsets.only(left: 10),
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
                    SizedBox(
                      key: _overseasCardKey,
                      width: double.infinity,
                      child: _TravelTypeCard(
                        title: 'overseas_travel_comma'.tr(),
                        description: 'overseas_description'.tr(),
                        iconPath: 'assets/icons/ico_Abroad.svg',
                        iconColor: const Color(0xFF6C5CE7),
                        onTap: () => _navigateToPage(
                          context,
                          const OverseasTravelDatePage(),
                        ),
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

                    // 🇺🇸 미국 여행
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
    super.key,
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
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: SvgPicture.asset(
                  iconPath,
                  width: 26,
                  height: 26,
                  color: isLocked ? const Color(0xFFCACBCC) : iconColor,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
