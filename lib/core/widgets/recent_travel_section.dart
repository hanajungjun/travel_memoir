import 'package:flutter/material.dart';

import 'package:travel_memoir/services/travel_service.dart';
import 'package:travel_memoir/services/travel_day_service.dart';
import 'package:travel_memoir/features/travel_diary/pages/travel_diary_list_page.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class HomeTravelStatusHeader extends StatelessWidget {
  final VoidCallback onGoToTravel;

  const HomeTravelStatusHeader({super.key, required this.onGoToTravel});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: TravelService.getTodayTravel(),
      builder: (context, snapshot) {
        final travel = snapshot.data;
        final isTraveling = travel != null;

        final title = isTraveling ? '${_title(travel)} 여행 중' : '지금은 여행 준비중';

        final subtitle = isTraveling
            ? '${travel!['start_date']} ~ ${travel['end_date']}'
            : '여행을 먼저 등록해볼까요?';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          color: isTraveling ? AppColors.primary : AppColors.lightSurface,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: isTraveling
                            ? AppColors.onPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: AppTextStyles.body.copyWith(
                        color: isTraveling
                            ? AppColors.onPrimary.withOpacity(0.9)
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () async {
                  if (!isTraveling) {
                    onGoToTravel();
                    return;
                  }

                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TravelDiaryListPage(travel: travel),
                    ),
                  );
                },
                child: Container(
                  width: 36,
                  height: 36,
                  color: isTraveling
                      ? AppColors.onPrimary.withOpacity(0.2)
                      : AppColors.divider,
                  child: Icon(
                    Icons.add,
                    color: isTraveling
                        ? AppColors.onPrimary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _title(Map<String, dynamic>? travel) {
    if (travel == null) return '';
    if (travel['travel_type'] == 'domestic') {
      return travel['city_name'] ?? travel['city'] ?? '국내';
    }
    return travel['country_name'] ?? '해외';
  }
}
