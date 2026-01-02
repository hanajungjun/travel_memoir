import 'package:flutter/material.dart';

import 'package:travel_memoir/services/travel_list_service.dart';
import 'package:travel_memoir/features/travel_diary/pages/travel_diary_list_page.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class RecentTravelSection extends StatelessWidget {
  final VoidCallback onSeeAll;

  const RecentTravelSection({super.key, required this.onSeeAll});

  static const int _maxCards = 3;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: TravelListService.getRecentTravels(),
      builder: (context, snapshot) {
        final travels = snapshot.data ?? [];

        final displayTravels = travels.take(_maxCards).toList();
        final emptyCount = _maxCards - displayTravels.length;
        final showSeeAll = travels.length > _maxCards;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== 타이틀 =====
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('최근 여행', style: AppTextStyles.sectionTitle),
                if (showSeeAll)
                  GestureDetector(
                    onTap: onSeeAll,
                    child: Text(
                      'See all',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // ===== 카드 3칸 =====
            Row(
              children: [
                ...displayTravels.map(
                  (travel) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _RecentTravelCard(travel: travel),
                    ),
                  ),
                ),

                // 빈 카드 채우기
                for (int i = 0; i < emptyCount; i++)
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: _EmptyTravelCard(),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ===================================================================
// 카드
// ===================================================================

class _RecentTravelCard extends StatelessWidget {
  final Map<String, dynamic> travel;

  const _RecentTravelCard({required this.travel});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TravelDiaryListPage(travel: travel),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== 지도 이미지 =====
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1,
                child: travel['map_image_url'] != null
                    ? Image.network(travel['map_image_url'], fit: BoxFit.cover)
                    : Container(color: AppColors.divider),
              ),
            ),

            const SizedBox(height: 10),

            // ===== 국내 / 해외 =====
            Text(
              travel['travel_type'] == 'domestic' ? '국내' : '해외',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 4),

            // ===== 기간 텍스트 =====
            Text(
              _periodText(travel),
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  String _periodText(Map<String, dynamic> travel) {
    final start = DateTime.tryParse(travel['start_date'] ?? '');
    final end = DateTime.tryParse(travel['end_date'] ?? '');

    if (start == null) return '';

    // 당일치기
    if (end == null || start.isAtSameMomentAs(end)) {
      return '당일치기';
    }

    final days = end.difference(start).inDays + 1;
    final nights = days - 1;

    return '${nights}박 ${days}일';
  }
}

// ===================================================================
// 빈 카드
// ===================================================================

class _EmptyTravelCard extends StatelessWidget {
  const _EmptyTravelCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(color: AppColors.divider),
        ),
      ),
    );
  }
}
