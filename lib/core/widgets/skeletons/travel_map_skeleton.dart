import 'package:flutter/material.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/core/widgets/skeletons/skeleton_box.dart';

class TravelMapSkeleton extends StatelessWidget {
  const TravelMapSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 380,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const SkeletonBox(
        width: double.infinity,
        height: double.infinity,
        radius: 12,
      ),
    );
  }
}
