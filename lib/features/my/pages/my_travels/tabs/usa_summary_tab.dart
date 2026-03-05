import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/features/map/pages/usa_map_page.dart';
import 'package:travel_memoir/services/usa_travel_summary_service.dart';
import 'package:travel_memoir/features/my/pages/my_travels/widgets/travel_summary_common_widgets.dart';

class UsaSummaryTab extends StatelessWidget {
  final String userId;

  // 🎯 MyTravelSummaryPage에서 고유 Key와 함께 호출되므로 생성자 유지
  const UsaSummaryTab({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        // [0] 방문한 주(State) 수
        UsaTravelSummaryService.getVisitedStateCount(userId: userId),

        // [1] 전체 미국 여행 횟수
        UsaTravelSummaryService.getTravelCount(userId: userId),

        // [2] 완성된 추억 개수
        UsaTravelSummaryService.getCompletedMemoriesCount(userId: userId),

        // [3] 총 미국 여행 일수
        UsaTravelSummaryService.getTotalTravelDays(userId: userId),

        // [4] 최다 방문 주 리스트
        UsaTravelSummaryService.getMostVisitedStates(userId: userId),
      ]),
      builder: (context, snapshot) {
        // 1. 데이터 로딩 중 (스켈레톤 UI)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MyTravelSummarySkeleton();
        }

        // 2. 에러 처리
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(child: Text('error_loading_data'.tr()));
        }

        final data = snapshot.data!;

        // 🎯 데이터 매핑
        final visitedStateCount = data[0] as int;
        final totalVisitCount = data[1] as int;
        final completedMemoriesCount = data[2] as int;
        final travelDays = data[3] as int;
        final mostVisitedList = data[4] as List<String>;

        // 최다 방문지 텍스트 처리
        String mostVisitedText;
        if (mostVisitedList.isEmpty) {
          mostVisitedText = '-';
        } else if (mostVisitedList.length <= 2) {
          mostVisitedText = mostVisitedList.join(', ');
        } else {
          mostVisitedText = '${mostVisitedList.take(2).join(', ')}...';
        }

        const int totalStateCount = 50;

        return Column(
          children: [
            // 1. 도넛 차트 (방문율)
            Padding(
              padding: const EdgeInsets.fromLTRB(34, 10, 27, 10),
              child: TotalDonutCard(
                visited: visitedStateCount,
                total: totalStateCount,
                activeColor: AppColors.travelingRed, // 빨간색 추가!
                title: 'in_total'.tr(),
                sub: 'visited_states'.tr(),
                percent: totalStateCount == 0
                    ? 0
                    : (visitedStateCount / totalStateCount * 100).round(),
              ),
            ),

            // 2. 🗺️ 미국 지도 (이동 및 확대 가능)
            const Expanded(
              child: SizedBox(
                width: double.infinity,
                child: UsaMapPage(
                  isReadOnly: false, // 🎯 이동 가능하도록 false 설정
                ),
              ),
            ),

            // 3. 통계 카드 요약
            Padding(
              padding: const EdgeInsets.fromLTRB(27, 27, 27, 0),
              child: CommonTravelSummaryCard(
                travelCount: totalVisitCount,
                completedCount: completedMemoriesCount,
                travelDays: travelDays,
                mostVisited: mostVisitedText,
                mostVisitedLabel: 'state'.tr(),
              ),
            ),
          ],
        );
      },
    );
  }
}
