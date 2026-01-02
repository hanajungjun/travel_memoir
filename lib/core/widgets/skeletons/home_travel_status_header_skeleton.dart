import 'package:flutter/material.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/core/widgets/skeletons/skeleton_box.dart';

class HomeTravelStatusHeaderSkeleton extends StatelessWidget {
  const HomeTravelStatusHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      color: AppColors.lightSurface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 텍스트 영역
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 160, height: 22, radius: 6),
                SizedBox(height: 8),
                SkeletonBox(width: 120, height: 14, radius: 6),
              ],
            ),
          ),

          // + 버튼 자리
          const SkeletonBox(width: 36, height: 36, radius: 4),
        ],
      ),
    );
  }
}
