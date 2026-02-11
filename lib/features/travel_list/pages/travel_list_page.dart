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
import 'package:travel_memoir/core/widgets/skeletons/travel_list_skeleton.dart';
import 'package:travel_memoir/core/widgets/popup/app_toast.dart';

/**
 * 📱 Screen ID : TRAVEL_LIST_PAGE
 * 📝 Name      : 여행 기록 목록 (Archive)
 * 🛠 Feature   : 
 * - 전체 여행 리스트 조회 및 실시간 삭제(Slidable) 기능
 * - FAB를 통한 신규 여행 생성 프로세스 진입
 * - RouteObserver를 활용하여 상세 페이지 복귀 시 데이터 자동 Refresh
 * - 국가/지역별 동적 배지 컬러링 및 작성 진행률 노출
 * * [ UI Structure ]
 * ----------------------------------------------------------
 * travel_list_page.dart (Scaffold)
 * ├── CustomScrollView (Body)
 * │    ├── CupertinoSliverRefreshControl [당겨서 새로고침]
 * │    └── SliverList (Travel List)
 * │         └── _SwipeDeleteItem (Slidable)
 * │              └── _TravelListItem [배지, 지역명, 날짜, 작성률]
 * └── FloatingActionButton [새 여행 추가 버튼]
 * ----------------------------------------------------------
 */
class TravelListPage extends StatefulWidget {
  const TravelListPage({super.key});

  @override
  State<TravelListPage> createState() => _TravelListPageState();
}

class _TravelListPageState extends State<TravelListPage> with RouteAware {
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
      backgroundColor: const Color(0xFFF6F6F6),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          // ✅ 슬라이더 자동 닫기 기능 유지
          return SlidableAutoCloseBehavior(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                const CupertinoSliverRefreshControl(onRefresh: null),

                if (snapshot.connectionState == ConnectionState.waiting)
                  const SliverToBoxAdapter(child: TravelListSkeleton())
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
                      10 + MediaQuery.of(context).padding.bottom,
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
                                // ✅ 1. 삭제 로직 실행
                                await TravelCreateService.deleteTravel(
                                  travel['id'],
                                );

                                // ✅ 2. 삭제 완료 토스트 메세지
                                if (mounted) {
                                  AppToast.show(
                                    context,
                                    'travel_delete_success'.tr(),
                                  );
                                  _refresh();
                                }
                              } catch (e) {
                                if (mounted) {
                                  AppToast.error(context, 'delete_error'.tr());
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
            ),
          );
        },
      ),
    );
  }

  // ( _buildFab, _SwipeDeleteItem, _TravelListItem 등 나머지 위젯 코드는 이전과 동일 )

  Widget _buildFab() {
    final double systemBottom = MediaQuery.of(context).padding.bottom;
    final double fabPadding = systemBottom > 0 ? systemBottom + 5 : 70;
    return Padding(
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

// _SwipeDeleteItem 및 _TravelListItem 위젯 코드는 기존 최적화 버전을 그대로 유지하시면 됩니다.
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
        motion: const BehindMotion(),
        extentRatio: 0.20,
        children: [
          CustomSlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: Colors.transparent,
            padding: const EdgeInsets.only(left: 6),
            child: Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.error,
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
  const _TravelListItem({super.key, required this.travel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final String travelType = travel['travel_type'] ?? '';
    final bool isDomestic = travelType == 'domestic';
    final bool isUSA = travelType == 'usa';
    final bool isKo = context.locale.languageCode == 'ko';

    String title = '';
    if (isDomestic || isUSA) {
      if (isKo) {
        // 한국어일 때는 기존처럼 region_name 출력 (예: 포항, 안양)
        title = travel['region_name'] ?? (isUSA ? 'USA' : '');
      } else {
        // 영어일 때는 region_id에서 마지막 단어만 추출 (예: KR_GG_SUWON -> SUWON)
        final String regId = travel['region_id']?.toString() ?? '';
        if (regId.contains('_')) {
          title = regId.split('_').last;
        } else {
          title = travel['region_name'] ?? (isUSA ? 'USA' : '');
        }
      }
    } else {
      // 해외(Global)는 기존의 다국어 대응 로직 유지
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
        final bool hasData = snapshot.hasData;
        final int written = snapshot.data ?? 0;
        final bool completed = hasData && written == totalDays && totalDays > 0;

        Color badgeColor;
        String badgeText;

        if (!hasData) {
          badgeColor = const Color(0xFFEEEEEE);
          badgeText = isUSA
              ? 'usa'.tr()
              : (isDomestic ? 'domestic'.tr() : 'overseas'.tr());
        } else if (completed) {
          badgeColor = const Color(0xFFBCBCBC);
          badgeText = isUSA
              ? 'usa'.tr()
              : (isDomestic ? 'domestic'.tr() : 'overseas'.tr());
        } else if (isUSA) {
          badgeColor = const Color(0xFFE74C3C);
          badgeText = 'usa'.tr();
        } else if (isDomestic) {
          badgeColor = const Color(0xFF289AEB);
          badgeText = 'domestic'.tr();
        } else {
          badgeColor = const Color(0xFF7C5FF6);
          badgeText = 'overseas'.tr();
        }

        return GestureDetector(
          // ✅ 수정 코드
          onTap: () async {
            // 1. 넘겨줄 데이터를 복사해서 영문/국문 title을 'display_name'으로 추가
            final Map<String, dynamic> modifiedTravel = Map.from(travel);
            modifiedTravel['display_name'] = title;

            // 2. 부모(TravelInfoPage)에서 정의한 이동 및 새로고침 로직 실행
            // 이 Navigator 코드를 여기서 직접 실행하면 _refresh() 오류를 피할 수 있어
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TravelDiaryListPage(travel: modifiedTravel),
              ),
            );

            // 3. 부모가 넘겨준 onTap 콜백을 실행해서 부모 쪽의 _refresh()가 돌게 함
            onTap();
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: hasData ? 1.0 : 0.5,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(6, 1, 6, 3),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: hasData
                                  ? AppColors.textColor02
                                  : Colors.transparent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                      if (hasData)
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
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w300,
                                color: const Color(0xFFA7A7A7),
                              ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 1),
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
