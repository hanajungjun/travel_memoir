import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class TotalTravelDonutCard extends StatelessWidget {
  final int visitedCount;
  final int totalCount;

  const TotalTravelDonutCard({
    super.key,
    required this.visitedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final double visitedRatio = totalCount == 0 ? 0 : visitedCount / totalCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // ======================
          // 🟢 도넛 차트
          // ======================
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    startDegreeOffset: -90,
                    sectionsSpace: 0,
                    centerSpaceRadius: 42,
                    sections: [
                      PieChartSectionData(
                        value: visitedRatio,
                        color: AppColors.primary,
                        radius: 18,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: 1 - visitedRatio,
                        color: const Color(0xFFE6E6E6),
                        radius: 18,
                        showTitle: false,
                      ),
                    ],
                  ),
                ),

                // ======================
                // 🔢 중앙 숫자
                // ======================
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$visitedCount',
                      style: AppTextStyles.pageTitle.copyWith(fontSize: 22),
                    ),
                    Text('/$totalCount', style: AppTextStyles.bodyMuted),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 20),

          // ======================
          // 📝 텍스트 설명
          // ======================
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('domestic_travel'.tr(), style: AppTextStyles.sectionTitle),
                const SizedBox(height: 6),
                Text(
                  'travel_destinations_visited'.tr(),
                  style: AppTextStyles.bodyMuted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
