import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/core/utils/date_utils.dart';
import 'package:travel_memoir/features/travel_album/pages/travel_album_page.dart';

// 🧭 상단 요약 히어로 카드 (기존 유지)
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

// 🧳 개별 여행 레코드 카드
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

    // ✅ 목적지 표시 텍스트 결정 로직 (실제 컬럼 기반)
    String destination;

    if (type == 'usa') {
      // 1. 미국 여행 (Arizona 등 표시)
      destination =
          travel['region_name'] ??
          travel['region_key'] ??
          (isKo ? '미국' : 'USA');
    } else if (type == 'domestic') {
      // 2. 국내 여행
      if (isKo) {
        destination = travel['region_name'] ?? 'unknown_destination'.tr();
      } else {
        final String rawKey = travel['region_key'] ?? '';
        destination = rawKey.isNotEmpty ? rawKey.split('_').last : 'Korea';
      }
    } else {
      // 3. 일반 해외 여행 (해당 국가명 표시)
      destination = isKo
          ? (travel['country_name_ko'] ?? 'unknown_destination'.tr())
          : (travel['country_name_en'] ??
                travel['country_code'] ??
                'unknown_destination'.tr());
    }

    final coverUrl = travel['cover_image_url'] as String?;
    final summary = (travel['ai_cover_summary'] ?? '').toString().trim();
    final hasCover = coverUrl != null;
    final hasSummary = summary.isNotEmpty;

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
                  child: hasCover
                      ? Image.network(
                          '$coverUrl?t=${travel['completed_at']}',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: AppColors.divider),
                        )
                      : Container(color: AppColors.divider),
                ),

                // ✅ 여행지 이름 (상단)
                Positioned(
                  top: 24,
                  left: 20,
                  right: 20,
                  child: Text(
                    destination,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900, // 에러 없는 가장 두꺼운 두께
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

                if (hasCover && !hasSummary)
                  BottomLabel(text: 'ai_organizing'.tr()),
                if (hasSummary) BottomLabel(text: summary, gradient: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 🏷️ 하단 텍스트 라벨 (공통 - 기존 유지)
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
