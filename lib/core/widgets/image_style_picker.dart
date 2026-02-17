import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/models/image_style_model.dart';
import 'package:travel_memoir/services/image_style_service.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/features/shop/page/shop_page.dart';
import 'package:travel_memoir/core/widgets/popup/app_dialogs.dart';

class ImageStylePicker extends StatefulWidget {
  final ValueChanged<ImageStyleModel> onChanged;

  const ImageStylePicker({super.key, required this.onChanged});

  @override
  State<ImageStylePicker> createState() => _ImageStylePickerState();
}

class _ImageStylePickerState extends State<ImageStylePicker> {
  List<ImageStyleModel> _styles = [];
  int _selectedIndex = -1;

  bool _isPremiumUser = false;
  bool _isVipUser = false; // ✅ [추가] VIP 여부 상태
  bool _isBoss = false;
  bool _isLoadingStatus = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await _checkUserStatus();
    await _loadStyles();
  }

  Future<void> _checkUserStatus() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // ✅ [수정] is_premium과 is_vip를 동시에 조회
        final res = await Supabase.instance.client
            .from('users')
            .select('is_premium, is_vip,role')
            .eq('auth_uid', user.id)
            .maybeSingle();

        if (mounted) {
          setState(() {
            _isPremiumUser = res?['is_premium'] ?? false;
            _isVipUser = res?['is_vip'] ?? false; // ✅ VIP 정보 업데이트
            _isBoss = res?['role'] == 'boss'; // ✅ Boss 체크
            _isLoadingStatus = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStatus = false);
    }
  }

  Future<void> _loadStyles() async {
    // 🎯 [핵심 수정] Boss라면 fetchAll (미사용 포함), 아니면 fetchEnabled (사용 중인 것만)
    List<ImageStyleModel> styles;
    if (_isBoss) {
      // ImageStyleService에 모든 스타일을 가져오는 메서드가 있다고 가정 (없으면 fetchEnabled 수정 필요)
      styles = await ImageStyleService.fetchAllForAdmin();
    } else {
      styles = await ImageStyleService.fetchEnabled();
    }

    if (!mounted) return;
    setState(() => _styles = styles);
  }

  // ✅ [도움 함수] 프리미엄 혹은 VIP 권한이 있는지 확인
  bool get _hasProAccess => _isPremiumUser || _isVipUser;

  void _showPremiumRequiredDialog() {
    AppDialogs.showAction(
      context: context,
      title: 'premium_only_style_title',
      message: 'premium_only_style_desc',
      actionLabel: 'go_to_shop',
      actionColor: const Color(0xFFFFB338),
      onAction: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ShopPage()),
        ).then((_) => _checkUserStatus());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_styles.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(child: Text('no_available_styles'.tr())),
      );
    }

    final String currentLang = context.locale.languageCode;

    return SizedBox(
      height: 105, // 텍스트 높이 고려하여 소폭 조정
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 0),
        itemCount: _styles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final style = _styles[i];
          final selected = i == _selectedIndex;
          final bool locked = style.isPremium && !_hasProAccess;

          final String displayTitle =
              (currentLang == 'en' && style.titleEn.isNotEmpty)
              ? style.titleEn
              : style.title;

          return GestureDetector(
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
              if (locked) {
                _showPremiumRequiredDialog();
              } else {
                setState(() => _selectedIndex = i);
                widget.onChanged(style);
              }
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    // 1. 이미지 썸네일
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.white,
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child:
                            style.thumbnailUrl != null &&
                                style.thumbnailUrl!.isNotEmpty
                            ? ColorFiltered(
                                colorFilter: ColorFilter.mode(
                                  locked ? Colors.grey : Colors.transparent,
                                  BlendMode.saturation,
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: Uri.encodeFull(style.thumbnailUrl!),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.image, color: Colors.grey),
                      ),
                    ),

                    // 2. [변경됨] 이미지 구석의 별표 아이콘 (PRO 글씨 대신)
                    if (style.isPremium)
                      const Positioned(
                        left: 3,
                        top: 3,
                        child: Icon(
                          Icons.stars_rounded, // 동그라미 안의 별 모양
                          color: Color.fromARGB(255, 255, 203, 59),
                          size: 16,
                        ),
                      ),

                    // 3. 선택 시 체크 표시
                    if (selected)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.travelingBlue.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 45,
                            ),
                          ),
                        ),
                      ),

                    // 4. 잠금 표시 (권한 없을 때)
                    if (locked)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.lock_rounded,
                              color: Color.fromARGB(150, 255, 255, 255),
                              size: 27,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                // 5. 스타일 이름 (별표 없이 텍스트만)
                SizedBox(
                  width: 72,
                  child: Text(
                    displayTitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMuted.copyWith(
                      fontSize: 11,
                      color: selected
                          ? AppColors.travelingBlue
                          : AppColors.textColor01,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
