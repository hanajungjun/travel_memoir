import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/core/constants/korea/korea_region_master.dart';
import 'package:travel_memoir/core/constants/korea/korea_region.dart';
import 'package:travel_memoir/features/map/pages/domestic_map_page.dart';
import 'package:travel_memoir/services/domestic_travel_summary_service.dart';
import 'package:travel_memoir/features/my/pages/my_travels/widgets/travel_summary_common_widgets.dart';

class DomesticSummaryTab extends StatelessWidget {
  final String userId;
  const DomesticSummaryTab({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([
        DomesticTravelSummaryService.getVisitedCityCount(userId: userId),
        DomesticTravelSummaryService.getTravelCount(
          userId: userId,
          isDomestic: true,
          isCompleted: true,
        ),
        DomesticTravelSummaryService.getTotalTravelDays(
          userId: userId,
          isDomestic: true,
          isCompleted: true,
        ),
        DomesticTravelSummaryService.getMostVisitedRegion(
          userId: userId,
          isDomestic: true,
          isCompleted: true,
        ),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MyTravelSummarySkeleton();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Center(child: Text("error_loading_data".tr()));
        }

        final data = snapshot.data!;

        final visitedCityCount = (data[0] as int?) ?? 0;
        final totalCityCount = koreaRegionMaster
            .where(
              (r) =>
                  r.type == KoreaRegionType.city ||
                  r.type == KoreaRegionType.county ||
                  r.mapRegionType == MapRegionType.special,
            )
            .length;

        final travelCount = (data[1] as int?) ?? 0;
        final travelDays = (data[2] as int?) ?? 0;

        final mostVisited = (data[3] as String?) ?? '-';

        return SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: TotalDonutCard(
                  visited: visitedCityCount,
                  total: totalCityCount,
                  sub: 'visited_cities'.tr(),
                  percent: totalCityCount == 0
                      ? 0
                      : (visitedCityCount / totalCityCount * 100).round(),
                ),
              ),
              const SizedBox(
                width: double.infinity,
                height: 350,
                child: AbsorbPointer(child: DomesticMapPage()),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: CommonTravelSummaryCard(
                  travelCount: travelCount,
                  travelDays: travelDays,
                  mostVisited: mostVisited,
                  mostVisitedLabel: 'region'.tr(),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }
}
