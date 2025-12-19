import 'package:flutter/material.dart';

import 'package:travel_memoir/services/travel_day_service.dart';
import 'package:travel_memoir/features/travel_day/pages/travel_day_page.dart';
import 'package:travel_memoir/core/utils/date_utils.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class TravelDiaryListPage extends StatelessWidget {
  final Map<String, dynamic> travel;

  const TravelDiaryListPage({super.key, required this.travel});

  @override
  Widget build(BuildContext context) {
    final startDate = DateTime.parse(travel['start_date']);
    final endDate = DateTime.parse(travel['end_date']);
    final totalDays = endDate.difference(startDate).inDays + 1;

    final isFinished = DateTime.now().isAfter(endDate);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        title: Row(
          children: [
            Text('${travel['city']} 여행 기록', style: AppTextStyles.appBarTitle),
            const SizedBox(width: 8),
            if (isFinished) const _FinishedBadge(),
          ],
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: totalDays,
        itemBuilder: (context, index) {
          final date = startDate.add(Duration(days: index));
          final dayIndex = index + 1;

          return FutureBuilder<Map<String, dynamic>?>(
            future: TravelDayService.getDiaryByDate(
              travelId: travel['id'],
              date: date,
            ),
            builder: (context, snapshot) {
              final diary = snapshot.data;
              final hasDiary =
                  diary != null && (diary['text'] ?? '').toString().isNotEmpty;

              final imageUrl = diary == null
                  ? null
                  : TravelDayService.getAiImageUrl(
                      travelId: travel['id'],
                      date: date,
                    );

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TravelDayPage(
                        travelId: travel['id'],
                        city: travel['city'],
                        startDate: startDate,
                        endDate: endDate,
                        date: date,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      // ======================
                      // 🖼 썸네일
                      // ======================
                      if (imageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            imageUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.divider,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                          ),
                        ),

                      const SizedBox(width: 14),

                      // ======================
                      // 📝 텍스트
                      // ======================
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${DateUtilsHelper.formatMonthDay(date)} · ${dayIndex}일차',
                              style: AppTextStyles.caption,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              hasDiary
                                  ? (diary!['text'] as String).split('\n').first
                                  : '아직 작성하지 않았어요',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: hasDiary
                                  ? AppTextStyles.body
                                  : AppTextStyles.bodyMuted,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      Icon(
                        hasDiary ? Icons.check_circle : Icons.edit,
                        color: hasDiary
                            ? AppColors.success
                            : AppColors.textDisabled,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==============================
// 🔒 여행 완료 배지
// ==============================
class _FinishedBadge extends StatelessWidget {
  const _FinishedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '여행완료',
        style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
