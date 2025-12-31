import 'package:flutter/material.dart';

import 'package:travel_memoir/services/travel_list_service.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/core/utils/date_utils.dart';

class RecentTravelSection extends StatelessWidget {
  const RecentTravelSection({super.key});

  static const int _maxCards = 3;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: TravelListService.getRecentTravels(),
      builder: (context, snapshot) {
        final travels = snapshot.data ?? [];
        final showSeeAll = travels.length >= 4;

        // 실제로 화면에 그릴 카드 목록 (최대 3개)
        final displayTravels = travels.take(_maxCards).toList();

        // 부족한 만큼 no_trip 채우기
        final emptyCount = _maxCards - displayTravels.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== 타이틀 + see all =====
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('최근 여행지', style: AppTextStyles.sectionTitle),
                if (showSeeAll)
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/travel'),
                    child: Text('see all', style: AppTextStyles.bodyMuted),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // ===== 카드 리스트 =====
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _maxCards,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  if (index < displayTravels.length) {
                    return _TravelCard(travel: displayTravels[index]);
                  }
                  return const _NoTripCard();
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// =====================================================
// ✅ 여행 카드
// =====================================================
class _TravelCard extends StatelessWidget {
  final Map<String, dynamic> travel;

  const _TravelCard({required this.travel});

  @override
  Widget build(BuildContext context) {
    final place =
        travel['region_name'] ??
        travel['city_name'] ??
        travel['city'] ??
        travel['country_name'] ??
        '여행';

    final period = DateUtilsHelper.periodText(
      startDate: travel['start_date'],
      endDate: travel['end_date'],
    );

    final imageUrl = travel['map_image_url'] ?? travel['cover_image_url'];

    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: imageUrl != null
                ? Image.network(
                    imageUrl,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 120,
                    height: 120,
                    color: AppColors.lightSurface,
                    child: const Icon(Icons.map_outlined, color: Colors.grey),
                  ),
          ),
          const SizedBox(height: 10),
          Text(
            '$place · $period',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// 🧳 여행 없음 카드 (no_trip)
// =====================================================
class _NoTripCard extends StatelessWidget {
  const _NoTripCard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Image.asset(
              'assets/images/no_trip.png', // 👈 이 경로 맞춰줘
              width: 120,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 10),
          Text('여행 준비 중', style: AppTextStyles.bodyMuted),
        ],
      ),
    );
  }
}
