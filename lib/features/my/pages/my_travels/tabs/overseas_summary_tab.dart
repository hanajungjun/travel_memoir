import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';

import 'package:travel_memoir/features/map/pages/global_map_page_%EC%9B%90%EB%B3%B8.dart';
import 'package:travel_memoir/services/overseas_travel_summary_service.dart';
import 'package:travel_memoir/features/my/pages/my_travels/widgets/travel_summary_common_widgets.dart';

class OverseasSummaryTab extends StatelessWidget {
  final String userId;
  const OverseasSummaryTab({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([
        // [0] 전 세계 국가 수
        OverseasTravelSummaryService.getTotalCountryCount(),

        // [1] 방문한 국가 수 (중복 제거, 완료된 여행 기준)
        OverseasTravelSummaryService.getVisitedCountryCount(userId: userId),

        // [2] 전체 해외 여행 횟수 (완료 여부 무관)
        OverseasTravelSummaryService.getTravelCount(
          userId: userId,
          isCompleted: null,
        ),

        // [3] 일기 작성 완료 여행 횟수
        OverseasTravelSummaryService.getTravelCount(
          userId: userId,
          isCompleted: true,
        ),

        // [4] 총 여행 일수 (완료 여부 무관)
        OverseasTravelSummaryService.getTotalTravelDays(
          userId: userId,
          isCompleted: null,
        ),

        // [5] 최다 방문 국가 리스트 (많이 간 순)
        OverseasTravelSummaryService.getMostVisitedCountries(
          userId: userId,
          isCompleted: null,
          langCode: context.locale.languageCode, // 🎯 현재 앱 언어 설정 전달
        ),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MyTravelSummarySkeleton();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          debugPrint("❌ 해외 요약 로딩 에러: ${snapshot.error}");
          return Center(child: Text('error_loading_data'.tr()));
        }

        final data = snapshot.data!;

        final totalCountries = data[0] as int;
        final visitedCountries = data[1] as int;
        final totalVisitCount = data[2] as int;
        final completedDiaryCount = data[3] as int;
        final travelDays = data[4] as int;
        final mostVisitedList = data[5] as List<String>;

        // 🌍 최다 방문 국가 표시용 가공
        String mostVisitedText;
        if (mostVisitedList.isEmpty) {
          mostVisitedText = '-';
        } else if (mostVisitedList.length <= 2) {
          mostVisitedText = mostVisitedList.join(', ');
        } else {
          mostVisitedText = '${mostVisitedList.take(2).join(', ')}...';
        }

        return Column(
          children: [
            // 🌍 1. 방문 국가 도넛 차트
            Padding(
              padding: const EdgeInsets.fromLTRB(34, 10, 27, 10),
              child: TotalDonutCard(
                visited: visitedCountries,
                total: totalCountries,
                activeColor: AppColors.travelingPurple, // 보라색 추가!
                title: 'in_total'.tr(),
                sub: 'countries'.tr(),
                percent: totalCountries == 0
                    ? 0
                    : (visitedCountries / totalCountries * 100).round(),
              ),
            ),

            // 🗺️ 2. 글로벌 지도
            const Expanded(
              child: SizedBox(
                width: double.infinity,
                child: GlobalMapPage(isReadOnly: true),
              ),
            ),

            // 📝 3. 요약 카드
            Padding(
              padding: const EdgeInsets.fromLTRB(27, 27, 27, 0),
              child: CommonTravelSummaryCard(
                travelCount: totalVisitCount,
                completedCount: completedDiaryCount,
                travelDays: travelDays,
                mostVisited: mostVisitedText,
                mostVisitedLabel: 'country'.tr(),
              ),
            ),
          ],
        );
      },
    );
  }
}
