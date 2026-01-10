import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class TravelCard extends StatelessWidget {
  final Map<String, dynamic> travel;
  final VoidCallback onTap;

  const TravelCard({super.key, required this.travel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCompleted = travel['is_completed'] == true;
    final coverUrl = _coverImageUrl(travel);

    final DecorationImage image = isCompleted && coverUrl != null
        ? DecorationImage(
            image: NetworkImage(coverUrl),
            fit: BoxFit.cover,
            onError: (_, __) {},
          )
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
          Text(
            'travel_with_city'.tr(args: [travel['city'] ?? '']),
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: 6),
          Text(
            '${travel['start_date']} ~ ${travel['end_date']}',
            style: AppTextStyles.bodyMuted,
          ),
        ],
      ),
    );
  }

  String? _coverImageUrl(Map<String, dynamic> travel) {
    final userId = travel['user_id'];
    final travelId = travel['id'];

    if (userId == null || travelId == null) return null;

    final path = 'users/$userId/travels/$travelId/cover.png';

    return Supabase.instance.client.storage
        .from('travel_images')
        .getPublicUrl(path);
  }
}
