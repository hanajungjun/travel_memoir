import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:travel_memoir/models/image_style_model.dart';
import 'package:travel_memoir/services/image_style_service.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/features/my/pages/shop/coin_shop_page.dart';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await _checkUserStatus();
    await _loadStyles();
    setState(() => _isLoading = false);
  }

  Future<void> _checkUserStatus() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final res = await Supabase.instance.client
            .from('users')
            .select('is_premium')
            .eq('auth_uid', user.id)
            .maybeSingle();

        if (mounted) {
          setState(() {
            _isPremiumUser = res?['is_premium'] ?? false;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadStyles() async {
    final styles = await ImageStyleService.fetchEnabled();
    if (mounted) setState(() => _styles = styles);
  }

  void _showPremiumRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'premium_only_style_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('premium_only_style_desc'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'close'.tr(),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CoinShopPage()),
              ).then((_) => _checkUserStatus());
            },
            child: Text(
              'go_to_shop'.tr(),
              style: const TextStyle(
                color: Colors.black,
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
    if (_isLoading)
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    if (_styles.isEmpty)
      return SizedBox(
        height: 100,
        child: Center(child: Text('no_available_styles'.tr())),
      );

    return SizedBox(
      height: 110,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _styles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final style = _styles[i];
          final bool isSelected = i == _selectedIndex;
          final bool isLocked = style.isPremium && !_isPremiumUser; // 🔥 잠금 로직

          return GestureDetector(
            onTap: () {
              if (isLocked) {
                _showPremiumRequiredDialog();
              } else {
                setState(() => _selectedIndex = i);
                widget.onChanged(style);
              }
            },
            child: Column(
              children: [
                Stack(
                  children: [
                    // 🖼 썸네일 베이스
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: AppColors.travelingBlue,
                                width: 3,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          isSelected ? 9 : 12,
                        ),
                        child: ColorFiltered(
                          // 🔒 잠겨있으면 채도를 0으로 (회색조)
                          colorFilter: ColorFilter.mode(
                            isLocked ? Colors.grey : Colors.transparent,
                            BlendMode.saturation,
                          ),
                          child:
                              style.thumbnailUrl != null &&
                                  style.thumbnailUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: Uri.encodeFull(style.thumbnailUrl!),
                                  fit: BoxFit.cover,
                                )
                              : const Icon(Icons.image, color: Colors.grey),
                        ),
                      ),
                    ),

                    // 🔒 잠금 오버레이
                    if (isLocked)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),

                    // ✅ 선택 체크 배지
                    if (isSelected)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppColors.travelingBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),

                    // 👑 PRO 배지
                    if (style.isPremium)
                      Positioned(
                        left: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(6),
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
                const SizedBox(height: 6),
                // 📝 스타일 제목 (언어 대응)
                SizedBox(
                  width: 76,
                  child: Text(
                    ImageStyleService.getLocalizedTitle(
                      style,
                      context,
                    ), // 🔥 헬퍼 사용
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMuted.copyWith(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? AppColors.travelingBlue
                          : AppColors.textColor01,
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
