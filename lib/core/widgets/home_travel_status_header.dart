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
  final VoidCallback onRefresh;

  const HomeTravelStatusHeader({
    super.key,
    required this.onGoToTravel,
    required this.onRefresh,
  });

  @override
  State<HomeTravelStatusHeader> createState() => _HomeTravelStatusHeaderState();
}

class _HomeTravelStatusHeaderState extends State<HomeTravelStatusHeader> {
  final StampService _stampService = StampService();

  // 👇 핵심: 이전 데이터를 캐싱
  Map<String, dynamic>? _cachedTravel;
  Map<String, dynamic>? _cachedStampData;
  bool _isFirstLoad = true; // 최초 로딩 여부

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // 👇 key 변경 시(부모가 refresh 요청 시) 재호출되도록
  @override
  void didUpdateWidget(HomeTravelStatusHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final results = await Future.wait([
      TravelService.getTodayTravel(),
      _stampService.getStampData(userId),
    ]);

    if (!mounted) return;
    setState(() {
      _cachedTravel = results[0] as Map<String, dynamic>?;
      _cachedStampData = results[1] as Map<String, dynamic>?;
      _isFirstLoad = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 👇 최초 로딩 시에만 스켈레톤, 이후엔 캐시 데이터로 바로 표시
    if (_isFirstLoad) {
      final String travelType = ''; // 아직 모르니까 gray
      return Container(
        color: AppColors.travelReadyGray,
        child: const SafeArea(
          bottom: false,
          child: HomeTravelStatusHeaderSkeleton(),
        ),
      );
    }

    final travel = _cachedTravel;
    final stampData = _cachedStampData;
    final type = travel?['travel_type'] ?? '';

    Color bgColor;
    if (travel == null) {
      bgColor = AppColors.travelReadyGray;
    } else if (type == 'domestic') {
      bgColor = AppColors.travelingBlue;
    } else if (type == 'usa') {
      bgColor = AppColors.travelingRed;
    } else {
      bgColor = AppColors.travelingPurple;
    }

    final String travelId = travel?['id']?.toString() ?? 'no-travel';

    return Container(
      key: ValueKey('header-ready-$travelId'),
      color: bgColor,
      child: SafeArea(
        bottom: false,
        child: _HeaderContent(
          travel: travel,
          stampData: stampData,
          onGoToTravel: widget.onGoToTravel,
          bgColor: bgColor,
          onRefresh: _loadData, // 👈 직접 연결
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
  final VoidCallback onRefresh;

  const _HeaderContent({
    super.key,
    required this.travel,
    this.stampData,
    required this.onGoToTravel,
    required this.bgColor,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final t = travel;
    final isTraveling = t != null;
    final isDomestic = t?['travel_type'] == 'domestic';
    final isKo = context.locale.languageCode == 'ko';

    // 1. 장소명(location) 결정
    // 1. 장소명(location) 결정
    final String location;
    if (isTraveling) {
      final travelType = t['travel_type']; // 타입 변수화

      if (isDomestic) {
        // [국내] 한국어/영어 구분
        if (isKo) {
          location = t['region_name'] ?? '국내';
        } else {
          final String regKey = t['region_key']?.toString() ?? '';
          location = regKey.contains('_')
              ? regKey.split('_').last.toUpperCase()
              : (t['region_name_en'] ?? 'KOREA');
        }
      } else if (travelType == 'usa') {
        // 🎯 [미국 전용] 영문 이름만 사용 (구분 필요 없음)
        // DB 컬럼명이 city_name 이나 region_name 인지 확인 후 맞춰주세요.
        location = t['city_name'] ?? t['region_name'] ?? 'USA';
      } else {
        // [기타 해외] 한국어/영어 구분
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
                              ), // 1. Traveling in
                              const TextSpan(text: ' '),
                              TextSpan(
                                text: loc,
                                style: AppTextStyles.homeTravelLocation,
                              ), // 2. Palestine
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
              if (travel == null) {
                onGoToTravel();
                return;
              }

              // 🎯 Navigator 결과값을 기다립니다.
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TravelDiaryListPage(travel: travel!),
                ),
              );

              // 🎯 결과가 true면 부모가 넘겨준 새로고침 함수를 실행!
              if (result == true) {
                onRefresh();
              }
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
