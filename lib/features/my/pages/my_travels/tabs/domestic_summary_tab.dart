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

        // [1] 전체 방문 횟수 (isCompleted를 아예 안 보내면 서비스에서 null로 처리되어 전체를 가져옵니다)
        DomesticTravelSummaryService.getTravelCount(
          userId: userId,
          isDomestic: true,
          // ✅ 서비스에서 required를 지웠으므로 이제 안 써도 에러가 안 납니다!
        ),

        // [2] 일기 작성 완료 횟수 (기존처럼 true 전달)
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
        final totalVisitCount = (data[1] as int?) ?? 0; // 전체 방문
        final completedDiaryCount = (data[2] as int?) ?? 0; // 일기 완료
        final travelDays = (data[3] as int?) ?? 0;
        final mostVisited = (data[4] as String?) ?? '-';

        final totalCityCount = koreaRegionMaster
            .where(
              (r) =>
                  r.type == KoreaRegionType.city ||
                  r.type == KoreaRegionType.county ||
                  r.mapRegionType == MapRegionType.special,
            )
            .length;

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
                  travelCount: totalVisitCount, // 전체 방문지 개수
                  completedCount: completedDiaryCount, // 일기 작성 완료 개수
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
