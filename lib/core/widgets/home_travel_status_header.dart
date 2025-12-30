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

        final bool isTraveling = travel != null;
        final String title = isTraveling
            ? '${_getTravelTitle(travel)} 여행 중'
            : '여행 준비중';

        final String subtitle = isTraveling
            ? '${travel!['start_date']} ~ ${travel['end_date']}'
            : '다음 여행을 준비해보세요';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 28, 20, 24),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 왼쪽 텍스트 영역
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: AppColors.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.onPrimary.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),

              // + 버튼
              GestureDetector(
                onTap: () async {
                  // 👉 기존 "오늘의 일기 쓰기" 로직 그대로
                  if (!isTraveling) {
                    onGoToTravel();
                    return;
                  }

                  final diary = await TravelDayService.getDiaryByDate(
                    travelId: travel!['id'],
                    date: DateTime.now(),
                  );

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
                  decoration: BoxDecoration(
                    color: AppColors.onPrimary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: AppColors.onPrimary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getTravelTitle(Map<String, dynamic> travel) {
    if (travel['travel_type'] == 'domestic') {
      return travel['city_name'] ?? travel['city'] ?? '국내';
    }
    return travel['country_name'] ?? '해외';
  }
}
