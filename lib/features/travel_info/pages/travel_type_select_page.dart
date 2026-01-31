import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/features/my/pages/map_management/map_management_page.dart';

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

  /// ✅ 구매 유도 팝업 (상점 연결 로직 추가)
  void _showPurchaseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'purchase_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'purchase_us_map_msg'.tr(),
        ), // "미국 지도가 필요합니다. 관리 화면으로 갈까요?"
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'cancel'.tr(),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // 팝업 닫기

              // 🎯 목적지를 MapManagementPage로 변경!
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MapManagementPage()),
              ).then((_) {
                // 관리 페이지에서 지도를 활성화하고 돌아올 수 있으니 다시 체크
                _checkMapAccess();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'go_to_management'.tr(), // "관리하러 가기" (다국어 키 추천)
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // ✅ 이 줄 추가
        // ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 27),
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
                            height: 1.4,
                          ),
                          children: [
                            TextSpan(
                              text: 'select_type_bold'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(
                              text: 'select_type_normal'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w100,
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
                      subTitleSuffix: 'abroad_label'.tr(),
                      description: 'overseas_description'.tr(),
                      icon: Icons.public_rounded,
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
                      subTitleSuffix: 'local_label'.tr(),
                      description: 'domestic_description'.tr(),
                      icon: Icons.location_on_rounded,
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
                      subTitleSuffix: 'us_label'.tr(),
                      description: 'us_description'.tr(),
                      icon: _hasUsaAccess
                          ? Icons.flag_rounded
                          : Icons.lock_rounded,
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
  final String subTitleSuffix;
  final String description;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final bool isLocked;

  const _TravelTypeCard({
    required this.title,
    required this.subTitleSuffix,
    required this.description,
    required this.icon,
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
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isLocked
                      ? Colors.grey.withOpacity(0.1)
                      : iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isLocked ? Colors.grey : iconColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 18,
                          color: const Color(0xFF111827),
                          fontWeight: FontWeight.w700,
                        ),
                        children: [
                          TextSpan(text: title),
                          TextSpan(
                            text: subTitleSuffix,
                            style: const TextStyle(
                              color: const Color(0xFF111827),
                              fontWeight: FontWeight.w200,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isLocked ? 'unlock_required'.tr() : description,
                      style: const TextStyle(
                        color: const Color(0xFF666666),
                        fontSize: 14,
                        fontWeight: FontWeight.w200,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLocked)
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.black12,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
