import 'package:flutter/material.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/core/widgets/skeletons/skeleton_box.dart';

class TravelInfoListSkeleton extends StatelessWidget {
  const TravelInfoListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ CustomScrollView(Sliver) 안에서 쓰기 위해 ListView 대신 Column으로 변경합니다.
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: List.generate(7, (index) {
          return Column(
            children: [
              const _TravelInfoItemSkeleton(),
              // 마지막 아이템 뒤에는 구분선을 넣지 않습니다.
              if (index < 6) Divider(height: 24, color: AppColors.divider),
            ],
          );
        }),
      ),
    );
  }
}

class _TravelInfoItemSkeleton extends StatelessWidget {
  const _TravelInfoItemSkeleton();

  @override
  Widget build(BuildContext context) {
    // 기존 디자인 유지를 위해 마진만 살짝 조정했습니다.
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 왼쪽 영역
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 48, height: 18, radius: 9),
                SizedBox(height: 8),
                SkeletonBox(width: 140, height: 18, radius: 6),
                SizedBox(height: 6),
                SkeletonBox(width: 120, height: 14, radius: 6),
              ],
            ),
          ),

          // 오른쪽 작성수
          const SkeletonBox(width: 56, height: 14, radius: 6),
        ],
      ),
    );
  }
}
