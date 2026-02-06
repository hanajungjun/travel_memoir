import 'package:flutter/material.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/core/widgets/skeletons/skeleton_box.dart';

class TravelDiaryListSkeleton extends StatelessWidget {
  const TravelDiaryListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      itemBuilder: (_, __) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: const [
                  SkeletonBox(width: 56, height: 56, radius: 10),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 120, height: 14),
                        SizedBox(height: 8),
                        SkeletonBox(width: double.infinity, height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 16, thickness: 0.6),
          ],
        );
      },
    );
  }
}
