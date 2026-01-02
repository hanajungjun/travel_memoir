import 'package:flutter/material.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/core/widgets/skeletons/skeleton_box.dart';

// ===============================
// 🦴 Skeleton Loading
// ===============================
class _MyTravelSummarySkeleton extends StatelessWidget {
  const _MyTravelSummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: const [
          // 도넛 카드 자리
          SkeletonBox(width: double.infinity, height: 120, radius: 20),
          SizedBox(height: 20),

          // 지도 자리
          SkeletonBox(width: double.infinity, height: 350, radius: 20),
          SizedBox(height: 24),

          // 여행 요약 카드 자리
          SkeletonBox(width: double.infinity, height: 140, radius: 20),
        ],
      ),
    );
  }
}
