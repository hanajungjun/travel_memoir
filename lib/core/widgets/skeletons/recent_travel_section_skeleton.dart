import 'package:flutter/material.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/core/widgets/skeletons/skeleton_box.dart';

class RecentTravelSectionSkeleton extends StatelessWidget {
  const RecentTravelSectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 타이틀
        const SkeletonBox(width: 120, height: 20, radius: 6),
        const SizedBox(height: 12),

        // 카드 3개
        Row(
          children: const [
            Expanded(child: _TravelCardSkeleton()),
            SizedBox(width: 12),
            Expanded(child: _TravelCardSkeleton()),
            SizedBox(width: 12),
            Expanded(child: _TravelCardSkeleton()),
          ],
        ),
      ],
    );
  }
}

class _TravelCardSkeleton extends StatelessWidget {
  const _TravelCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          // 이미지 영역
          SkeletonBox(width: double.infinity, height: 120, radius: 12),
          SizedBox(height: 10),

          // 여행지 이름
          SkeletonBox(width: 100, height: 14, radius: 6),
          SizedBox(height: 6),

          // 날짜
          SkeletonBox(width: 70, height: 12, radius: 6),
        ],
      ),
    );
  }
}
