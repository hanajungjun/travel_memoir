import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ 수파베이스 추가

import 'package:travel_memoir/models/image_style_model.dart';
import 'package:travel_memoir/services/image_style_service.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/features/my/pages/shop/coin_shop_page.dart'; // ✅ 상점 페이지 추가

class ImageStylePicker extends StatefulWidget {
  final ValueChanged<ImageStyleModel> onChanged;

  const ImageStylePicker({super.key, required this.onChanged});

  @override
  State<ImageStylePicker> createState() => _ImageStylePickerState();
}

class _ImageStylePickerState extends State<ImageStylePicker> {
  List<ImageStyleModel> _styles = [];
  int _selectedIndex = -1; // ✅ 아무것도 선택 안 된 상태

  // ✅ [수정] 진짜 프리미엄 여부 변수
  bool _isPremiumUser = false;
  bool _isLoadingStatus = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await _checkUserStatus(); // 유저 상태 먼저 확인
    await _loadStyles(); // 스타일 목록 로드
  }

  // ✅ [추가] 유저가 프리미엄인지 수파베이스에서 직접 확인
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

    setState(() {
      _styles = styles;
      // ❌ _selectedIndex 건들지 마라
    });
  }

  // ✅ [추가] 프리미엄 권유 팝업 (상점 연결)
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
              ).then((_) => _checkUserStatus()); // 상점 갔다 오면 상태 갱신
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

          // ✅ [핵심 로직] 스타일이 프리미엄용인데 유저가 일반 유저라면 '잠금'
          final bool locked = style.isPremium && !_isPremiumUser;

          final String displayTitle =
              (currentLang == 'en' && style.titleEn.isNotEmpty)
              ? style.titleEn
              : style.title;

          return GestureDetector(
            onTap: () {
              if (locked) {
                // 잠겨있으면 팝업 띄우고 선택 안 시켜줌
                _showPremiumRequiredDialog();
              } else {
                // 프리미엄이거나 일반 스타일이면 정상 선택
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
                      ),
                      clipBehavior: Clip.hardEdge, // ✅ 핵심 1
                      child: ClipRRect(
                        // ✅ 핵심 2
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
                                        fit: BoxFit.cover, // ✅ 꽉 참
                                      ),
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: Uri.encodeFull(
                                        style.thumbnailUrl!,
                                      ),
                                      fit: BoxFit.cover, // ✅ 꽉 참
                                    ))
                            : const Icon(Icons.image, color: Colors.grey),
                      ),
                    ),

                    // ✅ 선택됐을 때만 오버레이
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

                    // 🔒 자물쇠 아이콘 표시 (PRO 배지 옆에 추가)
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

                    // 👑 PRO 배지
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
                      color: AppColors.textColor01, // ✅ 색상 통일
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w400, // ✅ 선택 여부만 반영
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
