import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final imageUrl = _mapImageUrl(travel);

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
                child: imageUrl != null
                    ? Image.network(
                        '$imageUrl?t=${travel['completed_at']}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: AppColors.divider),
                      )
                    : Container(color: AppColors.divider),
              ),
            ),

            const SizedBox(height: 10),

            // ===== 국내 / 해외 =====
            Text(
              // 1순위: 대구, 부산 같은 지역 이름 (region_name)
              // 2순위: 그게 없으면 국가 이름 (country_name)
              // 3순위: 둘 다 없으면 '여행지'라고 표시
              (travel['region_name'] ?? travel['country_name'] ?? '여행지')
                  .toString(),
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

  // 🔥 핵심: map.png 경로 생성
  String? _mapImageUrl(Map<String, dynamic> travel) {
    return travel['map_image_url'] as String?;
  }

  String _periodText(Map<String, dynamic> travel) {
    final start = DateTime.tryParse(travel['start_date'] ?? '');
    final end = DateTime.tryParse(travel['end_date'] ?? '');

    if (start == null) return '';

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== 이미지 영역 (왼쪽 카드와 동일) =====
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                color: AppColors.divider,
                child: const Center(
                  child: Icon(
                    Icons.add_location_alt,
                    size: 34,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ===== 텍스트 영역 (국내/해외 위치와 동일한 레벨) =====
          Text(
            '여행을 추가해보세요',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
