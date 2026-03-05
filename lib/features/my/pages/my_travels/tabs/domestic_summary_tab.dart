import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';

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
        // [0] 전체 국내 여행 횟수 (전체)
        DomesticTravelSummaryService.getTravelCount(
          userId: userId,
          isDomestic: true,
          isCompleted: null,
        ),

        // [1] 완성된 추억 개수 (🔥 일기 다 쓴 여행만)
        DomesticTravelSummaryService.getCompletedMemoriesCount(
          userId: userId,
          isDomestic: true,
        ),

        // [2] 총 여행 일수 (전체 날짜 합)
        DomesticTravelSummaryService.getTotalTravelDays(
          userId: userId,
          isDomestic: true,
          isCompleted: null,
        ),

        // [3] 최다 방문 지역
        DomesticTravelSummaryService.getMostVisitedRegions(
          userId: userId,
          isDomestic: true,
          langCode: context.locale.languageCode,
        ).catchError((_) => <String>[]),
        // DomesticTravelSummaryService.getMostVisitedRegions(
        //   userId: userId,
        //   isDomestic: true,
        //   isCompleted: null,
        //   langCode: context.locale.languageCode, // 🎯 현재 언어 정보 추가
        // ),

        // [4]중복 없는 순수 방문 도시 수
        DomesticTravelSummaryService.getUniqueVisitedRegionsCount(
          userId: userId,
        ),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MyTravelSummarySkeleton();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Center(child: Text('error_loading_data'.tr()));
        }

        final data = snapshot.data!;

        // final visitedCityCount = data[0] as int;
        // final totalVisitCount = data[0] as int;
        // final completedMemoriesCount = data[1] as int;
        // final travelDays = data[2] as int;
        // final mostVisitedList = data[3] as List<String>;

        final totalVisitCount = data[0] as int; // 전체 여행 횟수 (예: 10회)
        final completedMemoriesCount = data[1] as int; // 완료된 추억
        final travelDays = data[2] as int; // 총 여행 일수
        final mostVisitedList = data[3] as List<String>;
        final visitedCityCount = data[4] as int; // 🎯 실제 방문한 도시 수 (예: 3곳)

        String mostVisitedText;
        if (mostVisitedList.isEmpty) {
          mostVisitedText = '-';
        } else if (mostVisitedList.length <= 2) {
          mostVisitedText = mostVisitedList.join(', ');
        } else {
          mostVisitedText = '${mostVisitedList.take(2).join(', ')}...';
        }

        final totalCityCount = koreaRegionMaster
            .where(
              (r) =>
                  r.type == KoreaRegionType.city ||
                  r.type == KoreaRegionType.county ||
                  r.mapRegionType == MapRegionType.special,
            )
            .length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(34, 10, 27, 10),
              child: TotalDonutCard(
                visited: visitedCityCount,
                total: totalCityCount,
                activeColor: AppColors.travelingBlue, // 파란색 추가!
                title: 'in_total'.tr(),
                sub: 'visited_cities'.tr(),
                percent: totalCityCount == 0
                    ? 0
                    : (visitedCityCount / totalCityCount * 100).round(),
              ),
            ),

            // 지도 - 남은 공간 유동적으로 채움
            const Expanded(
              child: SizedBox(
                width: double.infinity,
                child: DomesticMapPage(readOnly: true),
              ),
            ),

            // 요약 카드 하단 고정
            Padding(
              padding: const EdgeInsets.fromLTRB(27, 27, 27, 0),
              child: CommonTravelSummaryCard(
                travelCount: totalVisitCount,
                completedCount: completedMemoriesCount, // ✅ 여기
                travelDays: travelDays,
                mostVisited: mostVisitedText,
                mostVisitedLabel: 'region'.tr(),
              ),
            ),
          ],
        );
      },
    );
  }
}
