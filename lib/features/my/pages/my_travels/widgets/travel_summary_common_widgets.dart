import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/core/widgets/skeletons/skeleton_box.dart';

// 🧩 1. 공통 도넛 카드 (수정 없음)
class TotalDonutCard extends StatelessWidget {
  final int visited;
  final int total;
  final String? title;
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

// 🧩 2. 공통 여행 요약 카드 (에러 수정 완료)
class CommonTravelSummaryCard extends StatelessWidget {
  final int travelCount;
  final int completedCount;
  final int travelDays;
  final String mostVisited;
  final String mostVisitedLabel;

  const CommonTravelSummaryCard({
    super.key,
    required this.travelCount,
    required this.completedCount,
    required this.travelDays,
    required this.mostVisited,
    required this.mostVisitedLabel,
  });

  // ✅ 최다 방문 지역 가공 로직
  String _formatMostVisited(String rawText) {
    if (rawText.isEmpty || rawText == "-") return "-";
    List<String> locations = rawText.split(',').map((e) => e.trim()).toList();

    if (locations.length <= 2) {
      return rawText;
    } else {
      return "${locations[0]}, ${locations[1]} ...";
    }
  }

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

          // 🎯 함수 호출 시 파라미터 형식을 일치시켰습니다.
          _buildSummaryItem(
            'trip_count_label'.tr(),
            'count_unit'.tr(args: [travelCount.toString()]),
          ),
          const SizedBox(height: 12),
          _buildSummaryItem(
            'diary_completed_label'.tr(),
            'count_unit'.tr(args: [completedCount.toString()]),
          ),
          const SizedBox(height: 12),
          _buildSummaryItem(
            'total_days_label'.tr(),
            'day_unit'.tr(args: [travelDays.toString()]),
          ),
          const SizedBox(height: 12),
          _buildSummaryItem(
            'most_visited_format'.tr(args: [mostVisitedLabel]),
            _formatMostVisited(mostVisited),
          ),
        ],
      ),
    );
  }

  // 🎯 [에러 해결 핵심] 파라미터 정의에서 중괄호를 제거하여 위치 기반 방식으로 변경했습니다.
  Widget _buildSummaryItem(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
          ],

          // 왼쪽 라벨
          Text(label, style: AppTextStyles.bodyMuted.copyWith(fontSize: 14)),

          const SizedBox(width: 12),

          // 오른쪽 값 (오버플로우 방지)
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// 🧩 3. 공통 스켈레톤 (기존 유지)
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
