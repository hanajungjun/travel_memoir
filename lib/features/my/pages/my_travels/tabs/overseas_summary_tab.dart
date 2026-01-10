import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // 추가
import 'package:travel_memoir/features/map/pages/global_map_page.dart';
import 'package:travel_memoir/services/overseas_travel_summary_service.dart';
import '../widgets/travel_summary_common_widgets.dart';

class OverseasSummaryTab extends StatelessWidget {
  final String userId;
  const OverseasSummaryTab({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([
        OverseasTravelSummaryService.getTotalCountryCount(),
        OverseasTravelSummaryService.getVisitedCountryCount(userId: userId),
        OverseasTravelSummaryService.getTravelCount(userId: userId),
        OverseasTravelSummaryService.getTotalTravelDays(userId: userId),
        OverseasTravelSummaryService.getMostVisitedCountry(userId: userId),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MyTravelSummarySkeleton();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Center(child: Text("error_loading_data".tr()));
        }

        final total = snapshot.data![0] as int;
        final visited = snapshot.data![1] as int;
        final travelCount = snapshot.data![2] as int;
        final travelDays = snapshot.data![3] as int;
        final mostVisited = snapshot.data![4] as String;

        return SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: TotalDonutCard(
                  visited: visited,
                  total: total,
                  title: 'in_total'.tr(), // ✅ 번역 적용
                  sub: 'countries'.tr(), // ✅ 번역 적용
                  percent: total == 0 ? 0 : (visited / total * 100).round(),
                ),
              ),
              const SizedBox(
                width: double.infinity,
                height: 300,
                child: GlobalMapPage(isReadOnly: true),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: CommonTravelSummaryCard(
                  travelCount: travelCount,
                  travelDays: travelDays,
                  mostVisited: mostVisited,
                  mostVisitedLabel: 'country'.tr(), // ✅ 번역 적용
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
