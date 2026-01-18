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
      padding: const EdgeInsets.fromLTRB(33, 20, 24, 30),
      color: bgColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.sectionTitle.copyWith()),
                const SizedBox(height: 1),
                Text(subtitle, style: AppTextStyles.sectionText.copyWith()),
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
