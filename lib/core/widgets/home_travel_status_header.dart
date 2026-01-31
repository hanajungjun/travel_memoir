import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/services/travel_service.dart';
import 'package:travel_memoir/features/travel_diary/pages/travel_diary_list_page.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/core/widgets/skeletons/home_travel_status_header_skeleton.dart';

class HomeTravelStatusHeader extends StatefulWidget {
  final VoidCallback onGoToTravel;

  const HomeTravelStatusHeader({super.key, required this.onGoToTravel});

  @override
  State<HomeTravelStatusHeader> createState() => _HomeTravelStatusHeaderState();
}

class _HomeTravelStatusHeaderState extends State<HomeTravelStatusHeader> {
  // ✅ Future를 변수에 저장하여 리빌드 시 데이터가 다시 호출되는 것을 방지합니다.
  late Future<Map<String, dynamic>?> _todayTravelFuture;

  @override
  void initState() {
    super.initState();
    _todayTravelFuture = TravelService.getTodayTravel();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _todayTravelFuture,
      builder: (context, snapshot) {
        final travel = snapshot.data;
        final isTraveling = travel != null;
        final isDomestic = travel?['travel_type'] == 'domestic';

        final bgColor = isTraveling
            ? (isDomestic ? AppColors.travelingBlue : AppColors.travelingPurple)
            : AppColors.travelReadyGray;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          // ✅ 상태 변화에 따라 확실히 다른 위젯과 키를 반환하도록 분리했습니다.
          child: _buildAnimatedContent(snapshot, travel, bgColor),
        );
      },
    );
  }

  Widget _buildAnimatedContent(
    AsyncSnapshot<Map<String, dynamic>?> snapshot,
    Map<String, dynamic>? travel,
    Color bgColor,
  ) {
    // 1. 로딩 중일 때 (Skeleton)
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Container(
        key: const ValueKey('header-skeleton-state'), // ✅ 중복되지 않는 고유 키
        color: bgColor,
        child: const SafeArea(
          bottom: false,
          child: HomeTravelStatusHeaderSkeleton(),
        ),
      );
    }

    // 2. 데이터 로드가 완료되었을 때 (Content)
    return Container(
      key: const ValueKey('header-ready-state'), // ✅ 중복되지 않는 고유 키
      color: bgColor,
      child: SafeArea(
        bottom: false,
        child: _HeaderContent(
          travel: travel,
          onGoToTravel: widget.onGoToTravel,
          bgColor: bgColor,
        ),
      ),
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
                      final fullTitle = title;
                      final loc = location;
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
                  Text(subtitle, style: AppTextStyles.homeTravelInfo),
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
                color: AppColors.onPrimary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Image.asset(
                'assets/icons/ico_add.png',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
                color: AppColors.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
