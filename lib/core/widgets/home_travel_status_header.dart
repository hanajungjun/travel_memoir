import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ 추가
import 'package:travel_memoir/services/travel_service.dart';
import 'package:travel_memoir/services/stamp_service.dart'; // ✅ 추가
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
  // ✅ 여행 데이터와 스탬프 데이터를 동시에 관리하기 위해 Future 타입을 수정합니다.
  late Future<List<dynamic>> _headerDataFuture;
  final StampService _stampService = StampService();

  @override
  void initState() {
    super.initState();
    _headerDataFuture = _loadHeaderData();
  }

  // ✅ 여행 정보와 스탬프 정보를 한 번에 가져오는 묶음 함수
  Future<List<dynamic>> _loadHeaderData() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    return Future.wait([
      TravelService.getTodayTravel(),
      _stampService.getStampData(userId),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _headerDataFuture,
      builder: (context, snapshot) {
        // 데이터 구조 분해
        final travel = snapshot.data?[0] as Map<String, dynamic>?;
        final stampData = snapshot.data?[1] as Map<String, dynamic>?;

        // ✅ [VIP 로그 출력] 대표님 요청대로 vip_stamps를 로그로 찍습니다.
        if (stampData != null) {
          debugPrint(
            "🎫 [Header Stamp Log] Daily: ${stampData['daily_stamps']}, VIP: ${stampData['vip_stamps']}, Paid: ${stampData['paid_stamps']}, IS_VIP: ${stampData['is_vip']}",
          );
        }

        final isTraveling = travel != null;
        final type = travel?['travel_type'] ?? '';

        // ✅ [수정] 배경색 로직: 미국(usa) 케이스 명시적 추가
        Color bgColor;
        if (!isTraveling) {
          bgColor = AppColors.travelReadyGray;
        } else if (type == 'domestic') {
          bgColor = AppColors.travelingBlue;
        } else if (type == 'usa') {
          // 미국 여행 시 사용할 배경색 (현재는 Purple 유지, 필요시 변경 가능)
          bgColor = AppColors.travelingRed;
        } else {
          // 그 외 일반 해외 여행
          bgColor = AppColors.travelingPurple;
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _buildAnimatedContent(snapshot, travel, stampData, bgColor),
        );
      },
    );
  }

  Widget _buildAnimatedContent(
    AsyncSnapshot<List<dynamic>> snapshot,
    Map<String, dynamic>? travel,
    Map<String, dynamic>? stampData,
    Color bgColor,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Container(
        key: const ValueKey('header-skeleton-state'),
        color: bgColor,
        child: const SafeArea(
          bottom: false,
          child: HomeTravelStatusHeaderSkeleton(),
        ),
      );
    }

    return Container(
      key: const ValueKey('header-ready-state'),
      color: bgColor,
      child: SafeArea(
        bottom: false,
        child: _HeaderContent(
          travel: travel,
          stampData: stampData, // ✅ 스탬프 데이터 전달 (추후 UI 노출용)
          onGoToTravel: widget.onGoToTravel,
          bgColor: bgColor,
        ),
      ),
    );
  }
}

class _HeaderContent extends StatelessWidget {
  final Map<String, dynamic>? travel;
  final Map<String, dynamic>? stampData;
  final VoidCallback onGoToTravel;
  final Color bgColor;

  const _HeaderContent({
    super.key,
    required this.travel,
    this.stampData,
    required this.onGoToTravel,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = travel;
    final isTraveling = t != null;
    final isDomestic = t?['travel_type'] == 'domestic';
    final isKo = context.locale.languageCode == 'ko';

    // 1. 장소명(location) 결정
    final String location;
    if (isTraveling) {
      if (isDomestic) {
        if (isKo) {
          location = t['region_name'] ?? '국내';
        } else {
          final String regKey = t['region_key']?.toString() ?? '';
          location = regKey.contains('_')
              ? regKey.split('_').last.toUpperCase()
              : (t['region_name_en'] ?? 'KOREA');
        }
      } else {
        location =
            (isKo ? t['country_name_ko'] : t['country_name_en']) ?? 'Overseas';
      }
    } else {
      location = '';
    }

    // 2. 전체 타이틀 텍스트 (tr 활용)
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
                if (isTraveling)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: RichText(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      text: (() {
                        // 🎯 [핵심 수정] 언어에 따른 TextSpan 순서 교체
                        final loc = location;
                        final String statusText = title
                            .replaceFirst(loc, '')
                            .trim();

                        if (isKo) {
                          // 한국어: [울릉도] [여행 중]
                          return TextSpan(
                            children: [
                              TextSpan(
                                text: loc,
                                style: AppTextStyles.homeTravelLocation,
                              ),
                              const TextSpan(text: ' '),
                              TextSpan(
                                text: statusText,
                                style: AppTextStyles.homeTravelStatus,
                              ),
                            ],
                          );
                        } else {
                          // 영어: [Traveling in] [ULLEUNG]
                          return TextSpan(
                            children: [
                              TextSpan(
                                text: statusText,
                                style: AppTextStyles.homeTravelStatus,
                              ),
                              const TextSpan(text: ' '),
                              TextSpan(
                                text: loc,
                                style: AppTextStyles.homeTravelLocation,
                              ),
                            ],
                          );
                        }
                      })(),
                    ),
                  )
                else
                  Text(
                    title,
                    style: AppTextStyles.homeTravelTitleIdle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 0),
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
