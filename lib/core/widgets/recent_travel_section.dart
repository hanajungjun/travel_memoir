import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:travel_memoir/services/travel_list_service.dart';
import 'package:travel_memoir/features/travel_diary/pages/travel_diary_list_page.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

import 'package:travel_memoir/storage_urls.dart'; // ✅ 추가 (StorageUrls 사용)

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

  // ✅ map_image_url(path) → public URL 변환
  String? _resolveMapImageUrl(Map<String, dynamic> travel) {
    final raw = travel['map_image_url'] as String?;
    if (raw == null || raw.isEmpty) return null;

    final String type = travel['travel_type'] ?? 'domestic';

    if (type == 'domestic') {
      return StorageUrls.domesticMapFromPath(raw);
    }
    if (type == 'usa') {
      return StorageUrls.usaMapFromPath(raw);
    }
    // overseas
    return StorageUrls.globalMapFromPath(raw);
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveMapImageUrl(travel); // ✅ 여기만 바뀜
    final String destinationName = _getDestinationName(context, travel);

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
              child: (imageUrl != null && imageUrl.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: Uri.encodeFull(imageUrl),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.lightSurface,
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.divider,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.divider,
                        child: const Icon(
                          Icons.map_outlined,
                          color: Colors.white,
                        ),
                      ),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getDestinationName(
    BuildContext context,
    Map<String, dynamic> travel,
  ) {
    final String type = travel['travel_type'] ?? 'domestic';
    final bool isKo = context.locale.languageCode == 'ko';

    if (type == 'usa') {
      String name =
          travel['region_name'] ??
          travel['region_key'] ??
          (isKo ? '미국' : 'USA');
      return name.toUpperCase();
    }

    if (type == 'domestic') {
      if (isKo) return travel['region_name'] ?? 'unknown_destination'.tr();
      final String rawKey = travel['region_key'] ?? '';
      return rawKey.isNotEmpty ? rawKey.split('_').last.toUpperCase() : 'KOREA';
    }
    return isKo
        ? (travel['country_name_ko'] ?? 'unknown_destination'.tr())
        : (travel['country_name_en'] ??
              travel['country_code'] ??
              'unknown_destination'.tr());
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
