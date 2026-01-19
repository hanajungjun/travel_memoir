import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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
            ? (isDomestic ? AppColors.travelingBlue : AppColors.travelingPurple)
            : AppColors.travelReadyGray;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Container(
            key: snapshot.connectionState == ConnectionState.waiting
                ? const ValueKey('header-skeleton-bg')
                : const ValueKey('header-content-bg'),
            color: bgColor,
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

    final String location;
    if (isTraveling) {
      if (isDomestic) {
        location = t['region_name'] ?? t['city_name'] ?? 'domestic'.tr();
      } else {
        location =
            (context.locale.languageCode == 'ko'
                ? t['country_name_ko']
                : t['country_name_en']) ??
            'overseas'.tr();
      }
    } else {
      location = '';
    }

    final title = isTraveling
        ? 'traveling_status'.tr(args: [location])
        : 'preparing_travel'.tr();

    final subtitle = isTraveling
        ? '${t['start_date'] ?? ''} ~ ${t['end_date'] ?? ''}'
        : 'register_travel_first'.tr();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(33, 25, 24, 30),
      color: bgColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== 제목 =====
                if (isTraveling)
                  RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: (() {
                      final fullTitle = title; // "대구 여행중"
                      final loc = location; // "대구"
                      final rest = fullTitle.replaceFirst(loc, '').trim();

                      return TextSpan(
                        children: [
                          TextSpan(
                            text: loc,
                            style: AppTextStyles.homeTravelLocation,
                          ),
                          const TextSpan(text: ' '),
                          TextSpan(
                            text: rest,
                            style: AppTextStyles.homeTravelStatus,
                          ),
                        ],
                      );
                    })(),
                  )
                else
                  Text(
                    title,
                    style: AppTextStyles.homeTravelTitleIdle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                const SizedBox(height: 0),

                // ===== 서브타이틀 =====
                if (isTraveling)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/icons/ico_calendar.png',
                        width: 14,
                        height: 14,
                        color: AppColors.onPrimary.withOpacity(0.8),
                      ),
                      const SizedBox(width: 6),
                      Text(subtitle, style: AppTextStyles.homeTravelDate),
                    ],
                  )
                else
                  Text(subtitle, style: AppTextStyles.homeTravelDate),
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
                  builder: (_) => TravelDiaryListPage(travel: t),
                ),
              );
            },
            child: Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.onPrimary.withOpacity(0.15), // ✅ 배경색 하나만
                borderRadius: BorderRadius.circular(6), // ✅ 라운딩
              ),
              child: Image.asset(
                'assets/icons/ico_add.png', // ✅ 아이콘 이미지 하나만 사용
                width: 20,
                height: 20,
                fit: BoxFit.contain,
                color: AppColors.onPrimary, // 필요 없으면 지워도 됨
              ),
            ),
          ),
        ],
      ),
    );
  }
}
