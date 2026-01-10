import 'package:flutter/material.dart';
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
        // 1. 로딩 중일 때
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MyTravelSummarySkeleton();
        }

        // 2. 에러가 났거나 데이터가 아예 없을 때 안전장치
        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(child: Text("데이터를 불러오는 중 오류가 발생했습니다."));
        }

        // 💡 [핵심 수정] 데이터를 안전하게 꺼내고 null 처리하기
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

        // 데이터가 없으면 '-' 로 표시해서 에러 방지
        final mostVisited = (data[3] as String?) ?? '-';

        return SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: TotalDonutCard(
                  visited: visitedCityCount,
                  total: totalCityCount,
                  sub: '방문한 도시',
                  percent: totalCityCount == 0
                      ? 0
                      : (visitedCityCount / totalCityCount * 100).round(),
                ),
              ),
              const SizedBox(
                width: double.infinity,
                height: 350,
                // 지도가 없을 때도 터지지 않게 AbsorbPointer 유지
                child: AbsorbPointer(child: DomesticMapPage()),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: CommonTravelSummaryCard(
                  travelCount: travelCount,
                  travelDays: travelDays,
                  mostVisited: mostVisited,
                  mostVisitedLabel: '지역',
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
