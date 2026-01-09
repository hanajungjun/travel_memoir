import 'package:flutter/material.dart';
import 'package:travel_memoir/services/travel_list_service.dart';
import 'package:travel_memoir/features/travel_diary/pages/travel_diary_list_page.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

//TODO 최근 여행지 위젯
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
            // ===== 타이틀 & See All =====
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('최근 여행지', style: AppTextStyles.sectionTitle),
                if (showSeeAll)
                  GestureDetector(
                    onTap: onSeeAll,
                    child: Text(
                      'see all',
                      style: AppTextStyles.body.copyWith(
                        color: Colors.grey, // 스크린샷 느낌의 연한 색상
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

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
// 최근 여행 카드
// ===================================================================
class _RecentTravelCard extends StatelessWidget {
  final Map<String, dynamic> travel;
  const _RecentTravelCard({required this.travel});

  @override
  Widget build(BuildContext context) {
    final imageUrl = travel['map_image_url'] as String?;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TravelDiaryListPage(travel: travel),
          ),
        );
      },
      child: Column(
        children: [
          // ===== 이미지 영역 (모서리 곡률 조절) =====
          ClipRRect(
            borderRadius: BorderRadius.circular(20), // 스크린샷처럼 둥글게
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
          const SizedBox(height: 12),

          // ===== 지역명 & 여행 일수 (한 줄 표시 및 가운데 정렬) =====
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                // ✅ 언어 설정을 체크해서 한국어면 ko, 아니면 en 컬럼을 보여줍니다.
                '${travel['region_name'] ?? (View.of(context).platformDispatcher.locale.languageCode == 'ko' ? travel['country_name_ko'] : travel['country_name_en']) ?? '여행지'}',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              Text(
                _periodText(travel),
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _periodText(Map<String, dynamic> travel) {
    final start = DateTime.tryParse(travel['start_date'] ?? '');
    final end = DateTime.tryParse(travel['end_date'] ?? '');
    if (start == null) return '';
    if (end == null || start.isAtSameMomentAs(end)) return '당일치기';

    final days = end.difference(start).inDays + 1;
    final nights = days - 1;
    return '${nights}박 ${days}일';
  }
}

// ===================================================================
// 빈 카드 (디자인 통일)
// ===================================================================
class _EmptyTravelCard extends StatelessWidget {
  const _EmptyTravelCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              color: AppColors.lightSurface,
              child: const Center(
                child: Icon(
                  Icons.add_location_alt,
                  size: 30,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '여행 추가',
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
