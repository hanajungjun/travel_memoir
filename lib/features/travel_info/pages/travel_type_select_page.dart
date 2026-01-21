import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

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

  /// ✅ 구매 유도 팝업
  void _showPurchaseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'purchase_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('purchase_us_map_msg'.tr()),
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
              // TODO: 상점 페이지로 이동 또는 결제 로직 연결
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'go_to_shop'.tr(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 26,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                        children: [
                          TextSpan(
                            text: 'select_type_bold'.tr(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: 'select_type_normal'.tr()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

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

                    const SizedBox(height: 20),

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

                    const SizedBox(height: 20),
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

                    const SizedBox(height: 40),
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
  final bool isLocked; // ✅ 잠금 상태 여부 추가

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
        opacity: isLocked ? 0.5 : 1.0, // ✅ 잠금 시 투명도 조절 (Grey-out 효과)
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
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
                          fontSize: 20,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                        children: [
                          TextSpan(text: title),
                          TextSpan(
                            text: subTitleSuffix,
                            style: const TextStyle(
                              color: Colors.black45,
                              fontWeight: FontWeight.normal,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isLocked
                          ? 'unlock_required'.tr()
                          : description, // ✅ 잠금 시 설명 변경 가능
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLocked) // ✅ 우측에 작은 화살표 대신 자물쇠 아이콘 유지 가능
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
