import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'package:travel_memoir/app/route_observer.dart';
import 'package:travel_memoir/services/travel_list_service.dart';
import 'package:travel_memoir/services/travel_create_service.dart';
import 'package:travel_memoir/services/travel_day_service.dart';

import 'package:travel_memoir/features/travel_diary/pages/travel_diary_list_page.dart';
import 'package:travel_memoir/features/travel_info/pages/travel_type_select_page.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

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
  void didPopNext() {
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        toolbarHeight: 44,
      ),
      body: Column(
        children: [
          // 🔥 디버그 ID (절대 삭제 금지)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: Colors.black.withOpacity(0.04),
            child: const Text(
              'PAGE: TravelInfoPage',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final travels = snapshot.data!;
                if (travels.isEmpty) {
                  return const Center(
                    child: Text('아직 여행이 없어요', style: AppTextStyles.bodyMuted),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: travels.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 24, color: AppColors.divider),
                  itemBuilder: (context, index) {
                    final travel = travels[index];

                    return _SwipeDeleteItem(
                      travel: travel,
                      onDelete: () async {
                        await TravelCreateService.deleteTravel(travel['id']);
                        if (!mounted) return;
                        _refresh();

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('여행이 삭제되었습니다')),
                        );
                      },
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TravelDiaryListPage(travel: travel),
                          ),
                        );
                        _refresh();
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.travelingBlue,
        onPressed: () async {
          final created = await Navigator.push<Map<String, dynamic>>(
            context,
            MaterialPageRoute(builder: (_) => const TravelTypeSelectPage()),
          );

          if (!mounted) return;

          if (created != null) {
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
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}

// =====================================================
// 🔥 스와이프 삭제 아이템 (Slidable)
// =====================================================

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
        motion: const StretchMotion(), // 👈 살짝 튀어나오는 느낌
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: _TravelListItem(travel: travel, onTap: onTap),
    );
  }
}

// =====================================================
// 🧳 여행 카드 UI
// =====================================================

class _TravelListItem extends StatelessWidget {
  final Map<String, dynamic> travel;
  final VoidCallback onTap;

  const _TravelListItem({required this.travel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDomestic = travel['travel_type'] == 'domestic';

    final String title =
        travel['region_name'] ??
        travel['city_name'] ??
        travel['country_name'] ??
        '';

    final start = DateTime.parse(travel['start_date']);
    final end = DateTime.parse(travel['end_date']);
    final totalDays = end.difference(start).inDays + 1;

    return FutureBuilder<int>(
      future: TravelDayService.getWrittenDayCount(travelId: travel['id']),
      builder: (context, snapshot) {
        final written = snapshot.data ?? 0;
        final completed = written == totalDays;

        final badgeColor = completed
            ? AppColors.textSecondary
            : isDomestic
            ? AppColors.primary
            : AppColors.decoPurple;

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== 왼쪽 (뱃지 + 지역명) =====
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // ✅ 국내 / 해외 뱃지
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isDomestic ? '국내' : '해외',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: badgeColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // ✅ 지역명
                          Text(
                            title,
                            style: AppTextStyles.sectionTitle.copyWith(
                              color: completed
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${travel['start_date']} ~ ${travel['end_date']}',
                        style: AppTextStyles.bodyMuted,
                      ),
                    ],
                  ),
                ),

                // ===== 오른쪽 상단 작성 수 =====
                RichText(
                  text: TextSpan(
                    style: AppTextStyles.bodyMuted,
                    children: [
                      TextSpan(
                        text: '$written',
                        style: completed
                            ? AppTextStyles.bodyMuted
                            : AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                      ),
                      const TextSpan(text: ' / '),
                      TextSpan(text: '$totalDays 작성'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
