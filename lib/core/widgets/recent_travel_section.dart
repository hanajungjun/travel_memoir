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
                Text('recent_travels'.tr(), style: AppTextStyles.sectionTitle),
                if (showSeeAll)
                  GestureDetector(
                    onTap: onSeeAll,
                    child: Text(
                      'see_all'.tr(),
                      style: AppTextStyles.body.copyWith(color: Colors.grey),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${travel['region_name'] ?? (context.locale.languageCode == 'ko' ? travel['country_name_ko'] : travel['country_name_en']) ?? 'unknown_destination'.tr()}',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              Text(
                _periodText(context, travel),
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
          'add_travel'.tr(),
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
