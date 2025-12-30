import 'package:flutter/material.dart';
import 'package:travel_memoir/services/travel_list_service.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/core/utils/date_utils.dart';

class RecentTravelSection extends StatelessWidget {
  const RecentTravelSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔹 타이틀 + see all
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('최근 여행지', style: AppTextStyles.sectionTitle),
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/travel');
              },
              child: Text('see all', style: AppTextStyles.bodyMuted),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 🔹 최근 여행 카드
        FutureBuilder<List<Map<String, dynamic>>>(
          future: TravelListService.getRecentTravels(limit: 3),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 170,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final travels = snapshot.data!;
            if (travels.isEmpty) {
              return Text('최근 여행이 없어요', style: AppTextStyles.bodyMuted);
            }

            return SizedBox(
              height: 170,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: travels.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final travel = travels[index];

                  final place = _placeName(travel);
                  final period = DateUtilsHelper.periodText(
                    startDate: travel['start_date'],
                    endDate: travel['end_date'],
                  );

                  final mapImageUrl = travel['map_image_url'];

                  return SizedBox(
                    width: 120,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🗺️ 지도 이미지
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: mapImageUrl != null
                              ? Image.network(
                                  mapImageUrl,
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 120,
                                  height: 120,
                                  color: AppColors.surface,
                                  child: const Icon(
                                    Icons.map,
                                    color: Colors.grey,
                                  ),
                                ),
                        ),

                        const SizedBox(height: 8),

                        // 📍 도시 + 기간 (한 줄)
                        Text(
                          '$place · $period',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  /// 도시 / 지역 / 국가 이름 (국내/해외 사용 안 함)
  String _placeName(Map<String, dynamic> travel) {
    return travel['region_name'] ??
        travel['city_name'] ??
        travel['city'] ??
        travel['country_name'] ??
        '';
  }
}
