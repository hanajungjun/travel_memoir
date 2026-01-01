import 'package:flutter/material.dart';

import 'package:travel_memoir/services/travel_list_service.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/core/utils/date_utils.dart';

class RecentTravelSection extends StatelessWidget {
  final VoidCallback onSeeAll;

  const RecentTravelSection({super.key, required this.onSeeAll});

  static const int _maxCards = 3;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      // 🔥 여기서 4개까지 가져와서 "더 있는지"만 판단
      future: TravelListService.getRecentTravels(limit: 4),
      builder: (context, snapshot) {
        final travels = snapshot.data ?? [];

        // ✅ 4개면 → 실제론 더 있음 → see all 표시
        final bool showSeeAll = travels.length >= 4;

        // 화면에는 3개만
        final displayTravels = travels.take(_maxCards).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =========================
            // 타이틀 + see all
            // =========================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('최근 여행지', style: AppTextStyles.sectionTitle),
                if (showSeeAll)
                  GestureDetector(
                    onTap: onSeeAll, // ✅ AppShell 여행 탭으로 이동
                    child: Text('see all', style: AppTextStyles.bodyMuted),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // =========================
            // 카드 리스트
            // =========================
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _maxCards,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  if (index < displayTravels.length) {
                    final travel = displayTravels[index];
                    final mapImageUrl = travel['map_image_url'];

                    // ⏳ 지도 생성 중
                    if (mapImageUrl == null) {
                      return _LoadingTravelCard(travel: travel);
                    }

                    // ✅ 지도 생성 완료
                    return _TravelCard(travel: travel);
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
// ⏳ 지도 생성 중 카드 (정적)
// =====================================================
class _LoadingTravelCard extends StatelessWidget {
  final Map<String, dynamic> travel;

  const _LoadingTravelCard({required this.travel});

  @override
  Widget build(BuildContext context) {
    final place =
        travel['region_name'] ??
        travel['city_name'] ??
        travel['country_name'] ??
        '여행';

    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              width: 120,
              height: 120,
              color: AppColors.lightSurface,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      '지도 생성 중',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$place · 생성 중',
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
// 🗺️ 지도 생성 완료 카드 (map만 사용)
// =====================================================
class _TravelCard extends StatelessWidget {
  final Map<String, dynamic> travel;

  const _TravelCard({required this.travel});

  @override
  Widget build(BuildContext context) {
    final place =
        travel['region_name'] ??
        travel['city_name'] ??
        travel['country_name'] ??
        '여행';

    final period = DateUtilsHelper.periodText(
      startDate: travel['start_date'],
      endDate: travel['end_date'],
    );

    final String imageUrl = travel['map_image_url'];

    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Image.network(
              imageUrl,
              width: 120,
              height: 120,
              fit: BoxFit.cover,
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
// 🧳 여행 없음 카드
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
              'assets/images/no_trip.png',
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
