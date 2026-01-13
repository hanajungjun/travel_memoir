import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // 추가
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/core/widgets/skeletons/skeleton_box.dart';

// 🧩 1. 공통 도넛 카드
class TotalDonutCard extends StatelessWidget {
  final int visited;
  final int total;
  final String? title; // 기본값 처리를 위해 nullable로 변경
  final String sub;
  final int percent;

  const TotalDonutCard({
    super.key,
    required this.visited,
    required this.total,
    this.title,
    required this.sub,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ 기본값 'in_total' 번역 적용
                Text(title ?? 'in_total'.tr(), style: AppTextStyles.caption),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$visited',
                        style: AppTextStyles.pageTitle.copyWith(fontSize: 32),
                      ),
                      TextSpan(
                        text: ' / $total',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(sub, style: AppTextStyles.caption),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: total == 0 ? 0 : visited / total,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey.shade300,
                  color: AppColors.primary,
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CommonTravelSummaryCard extends StatelessWidget {
  final int travelCount; // 총 방문 횟수
  final int completedCount; // ✅ 추가: 일기 작성 완료 횟수 (is_completed == true)
  final int travelDays;
  final String mostVisited;
  final String mostVisitedLabel;

  const CommonTravelSummaryCard({
    super.key,
    required this.travelCount,
    required this.completedCount, // ✅ 필수 인자로 추가
    required this.travelDays,
    required this.mostVisited,
    required this.mostVisitedLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('travel_summary'.tr(), style: AppTextStyles.sectionTitle),
          const SizedBox(height: 16),
          // 1. 총 방문 횟수
          _buildSummaryItem(
            'trip_count_label'.tr(),
            'count_unit'.tr(args: [travelCount.toString()]),
          ),
          const SizedBox(height: 12),
          // 2. ✅ 일기 작성 완료 (새로 추가된 줄)
          _buildSummaryItem(
            'diary_completed_label'
                .tr(), // 번역 키 예: "일기 작성 완료" / "Diaries Completed"
            'count_unit'.tr(args: [completedCount.toString()]),
          ),
          const SizedBox(height: 12),
          // 3. 총 여행 일수
          _buildSummaryItem(
            'total_days_label'.tr(),
            'day_unit'.tr(args: [travelDays.toString()]),
          ),
          const SizedBox(height: 12),
          // 4. 최다 방문 지역
          _buildSummaryItem(
            'most_visited_format'.tr(args: [mostVisitedLabel]),
            mostVisited,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.body),
        Text(
          value,
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

// 🧩 3. 공통 스켈레톤 (텍스트가 없으므로 그대로 유지)
class MyTravelSummarySkeleton extends StatelessWidget {
  const MyTravelSummarySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          SkeletonBox(width: double.infinity, height: 120, radius: 20),
          SizedBox(height: 20),
          SkeletonBox(width: double.infinity, height: 350, radius: 20),
          SizedBox(height: 24),
          SkeletonBox(width: double.infinity, height: 140, radius: 20),
        ],
      ),
    );
  }
}
