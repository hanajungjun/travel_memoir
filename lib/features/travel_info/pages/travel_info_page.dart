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
              SliverAppBar(
                backgroundColor: const Color(0xFFF8F9FA),
                elevation: 0,
                pinned: true,
                centerTitle: true,
                title: Text(
                  'travel_records'.tr(),
                  style: AppTextStyles.sectionTitle,
                ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final travel = snapshot.data![index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
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
    return SizedBox(
      width: 60,
      height: 60,
      child: FloatingActionButton(
        elevation: 8,
        backgroundColor: AppColors.travelingBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
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
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            borderRadius: BorderRadius.circular(20),
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
    final isDomestic = travel['travel_type'] == 'domestic';
    final bool isKo = context.locale.languageCode == 'ko';

    // 🎯 [수정된 타이틀 로직]
    String title = '';
    if (isDomestic) {
      if (isKo) {
        title = travel['region_name'] ?? '';
      } else {
        // ✅ region_key가 있으면 '_'로 잘라서 마지막 단어(예: YEOJU)만 가져오고,
        // 없으면(null이면) 한글 이름이라도 보여줍니다.
        final String rawKey = travel['region_key'] ?? '';
        title = rawKey.isNotEmpty
            ? rawKey.split('_').last
            : (travel['region_name'] ?? '');
      }
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
        final badgeColor = completed
            ? const Color(0xFF9E9E9E)
            : isDomestic
            ? const Color(0xFF4A90E2)
            : const Color(0xFF9B51E0);

        return GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isDomestic ? 'domestic'.tr() : 'overseas'.tr(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: badgeColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                title, // ✅ 여기 title 하나로 통합해서 에러 해결!
                                style: AppTextStyles.sectionTitle.copyWith(
                                  fontSize: 18,
                                  color: completed
                                      ? Colors.grey
                                      : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '$start ~ $end',
                          style: AppTextStyles.bodyMuted.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                      children: [
                        TextSpan(
                          text: '$written',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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
