import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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
        // [0] 전 세계 국가 총수
        OverseasTravelSummaryService.getTotalCountryCount(),
        // [1] 방문한 국가 수 (중복 제외)
        OverseasTravelSummaryService.getVisitedCountryCount(userId: userId),

        // [2] ✅ 전체 해외 방문 횟수 (isCompleted 생략)
        OverseasTravelSummaryService.getTravelCount(userId: userId),

        // [3] ✅ 추가: 일기 작성 완료 횟수 (isCompleted: true)
        // 주의: 서비스 파일에서 이 파라미터를 받을 수 있게 수정되어 있어야 합니다!
        OverseasTravelSummaryService.getTravelCount(
          userId: userId,
          isCompleted: true,
        ),

        // [4] 총 여행 일수
        OverseasTravelSummaryService.getTotalTravelDays(userId: userId),
        // [5] 최다 방문 국가
        OverseasTravelSummaryService.getMostVisitedCountry(userId: userId),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MyTravelSummarySkeleton();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Center(child: Text("error_loading_data".tr()));
        }

        final data = snapshot.data!;

        // ✅ 인덱스 번호가 한 칸씩 밀린 것에 주의하세요!
        final total = data[0] as int;
        final visited = data[1] as int;
        final totalVisitCount = data[2] as int; // 전체 방문
        final completedDiaryCount = data[3] as int; // 일기 완료
        final travelDays = data[4] as int;
        final mostVisited = data[5] as String;

        return SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: TotalDonutCard(
                  visited: visited,
                  total: total,
                  title: 'in_total'.tr(),
                  sub: 'countries'.tr(),
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
                  travelCount: totalVisitCount, // 전체 방문지 개수
                  completedCount: completedDiaryCount, // ✅ 일기 작성 완료 개수
                  travelDays: travelDays,
                  mostVisited: mostVisited,
                  mostVisitedLabel: 'country'.tr(),
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
