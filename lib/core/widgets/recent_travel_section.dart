import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: Text(
                    'recent_travels'.tr(),
                    style: AppTextStyles.sectionTitle,
                  ),
                ),

                if (showSeeAll)
                  GestureDetector(
                    onTap: onSeeAll,
                    child: Text(
                      'see_all'.tr(),
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textColor04,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (int i = 0; i < _maxCards; i++) ...[
                  Expanded(
                    child: i < displayTravels.length
                        ? _RecentTravelCard(travel: displayTravels[i])
                        : const _EmptyTravelCard(),
                  ),
                  if (i != _maxCards - 1) const SizedBox(width: 12),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

class _RecentTravelCard extends StatelessWidget {
  final Map<String, dynamic> travel;
  const _RecentTravelCard({required this.travel});

  @override
  Widget build(BuildContext context) {
    final imageUrl = travel['map_image_url'] as String?;

    // 🎯 [다국어 대응 핵심 로직]
    final isDomestic = travel['travel_type'] == 'domestic';
    final bool isKo = context.locale.languageCode == 'ko';

    String destinationName = '';

    if (isDomestic) {
      if (isKo) {
        destinationName = travel['region_name'] ?? 'unknown_destination'.tr();
      } else {
        // 영어 모드일 때 region_key에서 마지막 단어만 추출 (예: KR_GG_YEOJU -> YEOJU)
        final String rawKey = travel['region_key'] ?? '';
        destinationName = rawKey.isNotEmpty
            ? rawKey.split('_').last
            : (travel['region_name'] ?? 'unknown_destination'.tr());
      }
    } else {
      // 해외 여행일 경우 국가명 처리
      destinationName = isKo
          ? (travel['country_name_ko'] ??
                travel['display_country_name'] ??
                'unknown_destination'.tr())
          : (travel['country_name_en'] ??
                travel['country_code'] ??
                'unknown_destination'.tr());
    }

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
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 1,
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: AppColors.divider),
                    )
                  : Container(color: AppColors.divider),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  destinationName,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _periodText(context, travel),
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13, // 카드의 좁은 공간을 위해 살짝 줄였습니다.
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _periodText(BuildContext context, Map<String, dynamic> travel) {
    final start = DateTime.tryParse(travel['start_date'] ?? '');
    final end = DateTime.tryParse(travel['end_date'] ?? '');
    if (start == null) return '';
    if (end == null || start.isAtSameMomentAs(end)) return 'day_trip'.tr();

    final days = end.difference(start).inDays + 1;
    final nights = days - 1;

    return 'travel_period_format'.tr(
      args: [nights.toString(), days.toString()],
    );
  }
}

class _EmptyTravelCard extends StatelessWidget {
  const _EmptyTravelCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              color: AppColors.lightSurface,
              child: Center(
                child: Image.asset(
                  'assets/images/no_trip.png',
                  width: 90,
                  height: 90,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text('add_travel'.tr(), style: AppTextStyles.listTitle),
      ],
    );
  }
}
