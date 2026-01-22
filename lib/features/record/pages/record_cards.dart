import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/core/utils/date_utils.dart';
import 'package:travel_memoir/features/travel_album/pages/travel_album_page.dart';
import 'package:travel_memoir/storage_urls.dart';

// =====================================================
// 🧭 [1] 상단 요약 히어로 카드
// =====================================================
class SummaryHeroCard extends StatelessWidget {
  final int totalCount;
  final Map<String, dynamic> lastTravel;

  const SummaryHeroCard({
    super.key,
    required this.totalCount,
    required this.lastTravel,
  });

  @override
  Widget build(BuildContext context) {
    final endDateStr = lastTravel['end_date']?.toString() ?? '';
    final end = DateTime.tryParse(endDateStr) ?? DateTime.now();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Text('memory_hero_title'.tr(), style: AppTextStyles.pageTitle),
            const SizedBox(height: 24),
            Text(
              'total_travels_format'.tr(args: [totalCount.toString()]),
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 8),
            Text(
              'last_travel_format'.tr(args: [DateUtilsHelper.formatYMD(end)]),
              style: AppTextStyles.body,
            ),
            Text(
              DateUtilsHelper.memoryTimeAgo(end),
              style: AppTextStyles.bodyMuted,
            ),
            const Spacer(),
            const Center(
              child: Icon(
                Icons.keyboard_arrow_up,
                size: 28,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// 🧳 [2] 개별 여행 레코드 카드 (신규 규칙 적용)
// =====================================================
class TravelRecordCard extends StatelessWidget {
  final Map<String, dynamic> travel;
  final VoidCallback onReturn;

  const TravelRecordCard({
    super.key,
    required this.travel,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    final isKo = context.locale.languageCode == 'ko';
    final type = travel['travel_type'] ?? 'domestic';

    // 🎯 목적지 표시 이름
    String destination;
    if (type == 'usa') {
      destination =
          travel['region_name'] ??
          travel['region_key'] ??
          (isKo ? '미국' : 'USA');
    } else if (type == 'domestic') {
      destination = isKo
          ? (travel['region_name'] ?? 'unknown_destination'.tr())
          : (travel['region_key'] ?? 'Korea');
    } else {
      destination = isKo
          ? (travel['country_name_ko'] ?? 'unknown_destination'.tr())
          : (travel['country_name_en'] ??
                travel['country_code'] ??
                'unknown_destination'.tr());
    }

    // ✅ 새 규칙: path → url
    final String? coverPath = travel['cover_image_url'];
    final String? imageUrl = coverPath != null
        ? StorageUrls.travelImage(coverPath)
        : null;

    final String summary = (travel['ai_cover_summary'] ?? '').toString().trim();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TravelAlbumPage(travel: travel),
              ),
            ).then((_) => onReturn());
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned.fill(
                  child: imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppColors.lightSurface,
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.divider,
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.divider,
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        )
                      : Container(color: AppColors.divider),
                ),

                // 🏷️ 여행지 이름
                Positioned(
                  top: 24,
                  left: 20,
                  right: 20,
                  child: Text(
                    destination,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.0,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          offset: Offset(0, 2),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),

                // 🤖 AI 요약
                if (imageUrl != null && summary.isEmpty)
                  BottomLabel(text: 'ai_organizing'.tr()),
                if (summary.isNotEmpty)
                  BottomLabel(text: summary, gradient: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// 🏷️ [3] 하단 텍스트 라벨
// =====================================================
class BottomLabel extends StatelessWidget {
  final String text;
  final bool gradient;

  const BottomLabel({super.key, required this.text, this.gradient = false});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: gradient
            ? const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              )
            : const BoxDecoration(color: Colors.black45),
        child: Text(
          text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body.copyWith(color: Colors.white, fontSize: 15),
        ),
      ),
    );
  }
}
