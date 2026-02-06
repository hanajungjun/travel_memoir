import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/models/image_style_model.dart';
import 'package:travel_memoir/services/image_style_service.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/features/my/pages/shop/coin_shop_page.dart';
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
            .select('is_premium, is_vip')
            .eq('auth_uid', user.id)
            .maybeSingle();

        if (mounted) {
          setState(() {
            _isPremiumUser = res?['is_premium'] ?? false;
            _isVipUser = res?['is_vip'] ?? false; // ✅ VIP 정보 업데이트
            _isLoadingStatus = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStatus = false);
    }
  }

  Future<void> _loadStyles() async {
    final styles = await ImageStyleService.fetchEnabled();
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
      actionColor: Colors.amber,
      onAction: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CoinShopPage()),
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
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _styles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final style = _styles[i];
          final selected = i == _selectedIndex;

          // ✅ [핵심 변경] locked 조건에 VIP 권한 합산
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
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: Colors.white,
                        border: selected
                            ? Border.all(
                                color: AppColors.travelingBlue,
                                width: 2,
                              )
                            : null,
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child:
                            style.thumbnailUrl != null &&
                                style.thumbnailUrl!.isNotEmpty
                            ? (locked
                                  ? ColorFiltered(
                                      colorFilter: const ColorFilter.mode(
                                        Colors.grey,
                                        BlendMode.saturation,
                                      ),
                                      child: CachedNetworkImage(
                                        imageUrl: Uri.encodeFull(
                                          style.thumbnailUrl!,
                                        ),
                                        width: 72, // 이미지 크기
                                        height: 72, // 이미지 크기
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: Uri.encodeFull(
                                        style.thumbnailUrl!,
                                      ),
                                      width: 72, // 이미지 크기
                                      height: 72, // 이미지 크기
                                      fit: BoxFit.cover,
                                    ))
                            : const Icon(Icons.image, color: Colors.grey),
                      ),
                    ),
                    if (selected)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.travelingBlue.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    if (locked)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.lock_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    if (style.isPremium)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                SizedBox(
                  width: 70,
                  child: Text(
                    displayTitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMuted.copyWith(
                      fontSize: 12,
                      color: AppColors.textColor01,
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
