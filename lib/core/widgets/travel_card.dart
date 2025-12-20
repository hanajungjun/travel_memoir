import 'package:flutter/material.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class TravelCard extends StatelessWidget {
  final Map<String, dynamic> travel;
  final VoidCallback onTap;

  const TravelCard({super.key, required this.travel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCompleted = travel['is_completed'] == true;
    final coverUrl = travel['cover_image_url'];

    final DecorationImage image = isCompleted && coverUrl != null
        ? DecorationImage(image: NetworkImage(coverUrl), fit: BoxFit.cover)
        : const DecorationImage(
            image: AssetImage('assets/images/travel_placeholder.png'),
            fit: BoxFit.cover,
          );

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: image,
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text('${travel['city']} 여행', style: AppTextStyles.sectionTitle),

          const SizedBox(height: 6),

          Text(
            '${travel['start_date']} ~ ${travel['end_date']}',
            style: AppTextStyles.bodyMuted,
          ),
        ],
      ),
    );
  }
}
