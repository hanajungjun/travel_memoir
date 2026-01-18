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

// 🧩 2. 공통 여행 요약 카드 (최다 방문 지역 로직 수정)
class CommonTravelSummaryCard extends StatelessWidget {
  final int travelCount;
  final int completedCount;
  final int travelDays; // ✅ 이 값은 호출하는 쪽에서 전체 합산값(is_completed 무관)을 넘겨줘야 함
  final String mostVisited; // 예: "서울, 부산, 제주, 도쿄"
  final String mostVisitedLabel;

  const CommonTravelSummaryCard({
    super.key,
    required this.travelCount,
    required this.completedCount,
    required this.travelDays,
    required this.mostVisited,
    required this.mostVisitedLabel,
  });

  // ✅ 최다 방문 지역 텍스트 정리 헬퍼 함수
  String _formatMostVisited(String rawText) {
    if (rawText.isEmpty) return "-";

    // 쉼표로 구분된 리스트로 변환
    List<String> locations = rawText.split(',').map((e) => e.trim()).toList();

    if (locations.length <= 2) {
      return rawText; // 2개 이하면 그대로 반환
    } else {
      // 2개까지만 합치고 뒤에 ... 추가
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
          // 📊 총 여행 일수 (데이터 집계 시 is_completed 필터가 빠졌는지 확인 필요)
          _buildSummaryItem(
            'total_days_label'.tr(),
            'day_unit'.tr(args: [travelDays.toString()]),
          ),
          const SizedBox(height: 12),
          _buildSummaryItem(
            'most_visited_format'.tr(args: [mostVisitedLabel]),
            _formatMostVisited(mostVisited), // ✅ 가공된 텍스트 적용
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
