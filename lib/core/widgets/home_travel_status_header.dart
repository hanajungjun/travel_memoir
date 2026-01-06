import 'package:flutter/material.dart';

import 'package:travel_memoir/services/travel_service.dart';
import 'package:travel_memoir/features/travel_diary/pages/travel_diary_list_page.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/core/widgets/skeletons/home_travel_status_header_skeleton.dart';

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
        final isDomestic = travel?['travel_type'] == 'domestic';

        final bgColor = isTraveling
            ? (isDomestic ? AppColors.primary : AppColors.decoPurple)
            : AppColors.lightSurface;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Container(
            key: snapshot.connectionState == ConnectionState.waiting
                ? const ValueKey('header-skeleton-bg')
                : const ValueKey('header-content-bg'),
            color: bgColor, // ✅ SafeArea 포함 색
            child: SafeArea(
              bottom: false,
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const HomeTravelStatusHeaderSkeleton()
                  : _HeaderContent(
                      travel: travel,
                      onGoToTravel: onGoToTravel,
                      bgColor: bgColor,
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderContent extends StatelessWidget {
  final Map<String, dynamic>? travel;
  final VoidCallback onGoToTravel;
  final Color bgColor;

  const _HeaderContent({
    super.key,
    required this.travel,
    required this.onGoToTravel,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = travel;
    final isTraveling = t != null;
    final isDomestic = t?['travel_type'] == 'domestic';

    final bool isKo =
        View.of(context).platformDispatcher.locale.languageCode == 'ko';

    final title = isTraveling
        ? (isDomestic
              ? '${(t['region_name'] ?? t['city_name'] ?? '국내')} 여행중' // 👈 t?['...'] 에서 ? 제거
              : '${((isKo ? t['country_name_ko'] : t['country_name_en']) ?? '해외')} 여행중') // 👈 t?['...'] 에서 ? 제거
        : '여행 준비중';

    final subtitle = isTraveling
        ? '${t?['start_date'] ?? ''} ~ ${t?['end_date'] ?? ''}'
        : '여행을 먼저 등록해볼까요?';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      color: bgColor, // ✅ 내부도 같은 색으로 (빈칸/네모 느낌 방지)
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
                  builder: (_) => TravelDiaryListPage(travel: t!),
                ),
              );
            },
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
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
  }
}
