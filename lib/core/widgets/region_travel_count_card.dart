import 'package:flutter/material.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class RegionTravelCountCard extends StatelessWidget {
  final String regionName;
  final int visitedCount;
  final int totalCount;

  const RegionTravelCountCard({
    super.key,
    required this.regionName,
    required this.visitedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // ======================
          // 🔢 큰 숫자
          // ======================
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(regionName, style: AppTextStyles.sectionTitle),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$visitedCount',
                    style: AppTextStyles.pageTitle.copyWith(fontSize: 28),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '/ $totalCount',
                      style: AppTextStyles.bodyMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // ======================
          // 📍 보조 텍스트
          // ======================
          Text('방문 완료', style: AppTextStyles.bodyMuted),
        ],
      ),
    );
  }
}
