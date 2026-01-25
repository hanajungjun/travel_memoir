import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lottie/lottie.dart';

import 'package:travel_memoir/app/route_observer.dart';
import 'package:travel_memoir/services/travel_list_service.dart';
import 'package:travel_memoir/services/travel_create_service.dart';
import 'package:travel_memoir/services/travel_day_service.dart';

import 'package:travel_memoir/features/travel_diary/pages/travel_diary_list_page.dart';
import 'package:travel_memoir/features/travel_info/pages/travel_type_select_page.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/core/widgets/skeletons/travel_info_list_skeleton.dart';

class TravelInfoPage extends StatefulWidget {
  const TravelInfoPage({super.key});

  @override
  State<TravelInfoPage> createState() => _TravelInfoPageState();
}

class _TravelInfoPageState extends State<TravelInfoPage> with RouteAware {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = TravelListService.getTravels();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _future = TravelListService.getTravels();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() => _refresh();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.endFloat, // ⭐⭐⭐ 이게 핵심
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              CupertinoSliverRefreshControl(
                refreshTriggerPullDistance: 120.0,
                refreshIndicatorExtent: 80.0,
                onRefresh: () async => _refresh(),
                builder:
                    (
                      context,
                      refreshState,
                      pulledExtent,
                      refreshTriggerPullDistance,
                      refreshIndicatorExtent,
                    ) {
                      double opacity =
                          (pulledExtent / refreshTriggerPullDistance).clamp(
                            0.0,
                            1.0,
                          );
                      return Center(
                        child: OverflowBox(
                          maxHeight: 150,
                          minHeight: 0,
                          child: Opacity(
                            opacity: opacity,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (pulledExtent > 30) ...[
                                  Lottie.asset(
                                    'assets/lottie/Earth globe rotating with Seamless loop animation.json',
                                    width: 100,
                                    fit: BoxFit.contain,
                                  ),
                                  Text(
                                    "pull_to_discover".tr(),
                                    style: AppTextStyles.bodyMuted.copyWith(
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverToBoxAdapter(child: TravelInfoListSkeleton())
              else if (!snapshot.hasData || snapshot.data!.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'no_travels_yet'.tr(),
                      style: AppTextStyles.bodyMuted,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    27,
                    65,
                    27,
                    100 +
                        MediaQuery.of(
                          context,
                        ).padding.bottom, // 하단 탭바 높이 + 시스템 바 여백만큼 추가
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final travel = snapshot.data![index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 13),
                        child: _SwipeDeleteItem(
                          travel: travel,
                          onDelete: () async {
                            try {
                              await TravelCreateService.deleteTravel(
                                travel['id'],
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(
                                  context,
                                ).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('travel_delete_success'.tr()),
                                    backgroundColor: Colors.black87,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                                _refresh();
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('delete_error'.tr())),
                                );
                              }
                            }
                          },
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    TravelDiaryListPage(travel: travel),
                              ),
                            );
                            _refresh();
                          },
                        ),
                      );
                    }, childCount: snapshot.data!.length),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFab() {
    // 1. 기기 하단 시스템 네비게이션 바의 실제 높이를 가져옵니다.
    //    (S23 3버튼 모드라면 약 48px 정도 잡힙니다.)
    final double systemBottom = MediaQuery.of(context).padding.bottom;

    // 2. 패딩 계산:
    //    - 시스템 바가 있을 때: 시스템 바(약 48) + 하단 탭바(약 70) + 여백(10) = 약 128~130
    //    - 시스템 바가 없을 때(아이폰/제스처): 기본 여백 포함 약 100~110
    //final double fabBottomPadding = systemBottom > 0 ? systemBottom + 85 : 100;
    final double fabPadding = systemBottom > 0 ? systemBottom + 5 : 70;
    return Padding(
      // padding: EdgeInsets.only(bottom: fabBottomPadding, right: 2),
      padding: EdgeInsets.only(bottom: fabPadding, right: 2),
      child: Material(
        color: Colors.transparent,
        elevation: 14,
        shadowColor: Colors.black.withOpacity(0.25),
        shape: const CircleBorder(),
        child: FloatingActionButton(
          elevation: 0,
          backgroundColor: AppColors.travelingBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          onPressed: () async {
            // ✅ 기존 로직 그대로 다 넣어놨습니다!
            final created = await Navigator.push<Map<String, dynamic>>(
              context,
              MaterialPageRoute(builder: (_) => const TravelTypeSelectPage()),
            );
            if (created != null && mounted) {
              _refresh();
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TravelDiaryListPage(travel: created),
                ),
              );
              _refresh();
            }
          },
          child: const Icon(Icons.add, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}

class _SwipeDeleteItem extends StatelessWidget {
  final Map<String, dynamic> travel;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _SwipeDeleteItem({
    required this.travel,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey(travel['id']),
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.18, // 버튼 + 여백 영역
        children: [
          const SizedBox(width: 13), // 카드 ↔ 버튼 간격
          CustomSlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: Colors.transparent, // ⭐ 핵심
            padding: EdgeInsets.zero,
            child: Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.error, // 🔴 여기만 빨강
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/icons/ico_delete.png',
                  width: 19,
                  height: 19,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      child: _TravelListItem(travel: travel, onTap: onTap),
    );
  }
}

class _TravelListItem extends StatelessWidget {
  final Map<String, dynamic> travel;
  final VoidCallback onTap;
  const _TravelListItem({required this.travel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // ✅ 여행 타입 구분 로직 확장
    final String travelType = travel['travel_type'] ?? '';
    final bool isDomestic = travelType == 'domestic';
    final bool isUSA = travelType == 'usa';
    final bool isKo = context.locale.languageCode == 'ko';

    // 🎯 타이틀 로직: 미국과 국내 여행 모두 region_name 활용
    String title = '';
    if (isDomestic || isUSA) {
      title = travel['region_name'] ?? (isUSA ? 'USA' : '');
    } else {
      title = isKo
          ? (travel['country_name_ko'] ?? '')
          : (travel['country_name_en'] ?? travel['country_code'] ?? '');
    }

    final start = travel['start_date']?.toString().replaceAll('-', '.') ?? '';
    final end = travel['end_date']?.toString().replaceAll('-', '.') ?? '';

    final startDate = DateTime.tryParse(travel['start_date'] ?? '');
    final endDate = DateTime.tryParse(travel['end_date'] ?? '');
    final int totalDays = (startDate != null && endDate != null)
        ? endDate.difference(startDate).inDays + 1
        : 0;

    return FutureBuilder<int>(
      future: TravelDayService.getWrittenDayCount(travelId: travel['id']),
      builder: (context, snapshot) {
        final written = snapshot.data ?? 0;
        final completed = written == totalDays && totalDays > 0;

        // ✅ 타입에 따른 배지 색상 결정
        Color badgeColor;
        String badgeText;

        if (completed) {
          badgeColor = const Color(0xFFBCBCBC);
          badgeText = isUSA
              ? 'usa'.tr()
              : (isDomestic ? 'domestic'.tr() : 'overseas'.tr());
        } else if (isUSA) {
          badgeColor = const Color(0xFFE74C3C); // 미국 레드
          badgeText = 'usa'.tr();
        } else if (isDomestic) {
          badgeColor = const Color(0xFF289AEB); // 국내 블루
          badgeText = 'domestic'.tr();
        } else {
          badgeColor = const Color(0xFF7C5FF6); // 해외 퍼플
          badgeText = 'overseas'.tr();
        }

        return GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(6, 2, 6, 4),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textColor02,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          title,
                          style: AppTextStyles.sectionTitle.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textColor01,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$written',
                              style: TextStyle(
                                fontWeight: completed
                                    ? FontWeight.w300
                                    : FontWeight.w700,
                                color: completed ? Colors.grey : Colors.black,
                              ),
                            ),
                            TextSpan(
                              text: 'written_days_format'.tr(
                                args: [totalDays.toString()],
                              ),
                            ),
                          ],
                        ),
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          color: const Color(0xFFA7A7A7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$start ~ $end',
                    style: AppTextStyles.bodyMuted.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w200,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
