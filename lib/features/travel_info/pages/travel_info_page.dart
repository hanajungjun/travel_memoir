import 'package:flutter/material.dart';
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

  // ======================
  // 🔥 새로고침
  // ======================
  void _refresh() {
    setState(() {
      _future = TravelListService.getTravels();
    });
  }

  // ======================
  // 🔥 route observer 연결
  // ======================
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

  // ======================
  // 🔥 다른 페이지 갔다가 돌아왔을 때
  // ======================
  @override
  void didPopNext() {
    debugPrint('🔥 TravelInfoPage didPopNext -> refresh');
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('내 여행', style: AppTextStyles.appBarTitle),
      ),
      body: Column(
        children: [
          // ===== 🔥 디버그 화면 아이디 (절대 삭제 금지) =====
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

          // ===== 실제 내용 =====
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final travels = snapshot.data ?? [];

                if (travels.isEmpty) {
                  return const Center(
                    child: Text('아직 여행이 없어요', style: AppTextStyles.bodyMuted),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: travels.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final travel = travels[index];

                    final isDomestic = travel['travel_type'] == 'domestic';

                    // ✅ 핵심 수정 포인트
                    final String titleText = isDomestic
                        ? (travel['region_name'] ?? '')
                        : (travel['country_name'] ?? '');

                    final startDate = DateTime.parse(travel['start_date']);
                    final endDate = DateTime.parse(travel['end_date']);
                    final totalDays = endDate.difference(startDate).inDays + 1;

                    final isFinished = DateTime.now().isAfter(endDate);

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDomestic
                            ? AppColors.surface
                            : AppColors.accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        TravelDiaryListPage(travel: travel),
                                  ),
                                );
                                if (!mounted) return;
                                _refresh();
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (!isDomestic) ...[
                                        const Icon(
                                          Icons.public,
                                          size: 18,
                                          color: AppColors.accent,
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Text(
                                        titleText,
                                        style: AppTextStyles.title.copyWith(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: isDomestic
                                              ? AppColors.textPrimary
                                              : AppColors.accent,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (isFinished) const _FinishedBadge(),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  FutureBuilder<int>(
                                    future: TravelDayService.getWrittenDayCount(
                                      travelId: travel['id'],
                                    ),
                                    builder: (context, snapshot) {
                                      final written = snapshot.data ?? 0;
                                      return Text(
                                        '$written / $totalDays일 작성',
                                        style: AppTextStyles.bodyMuted,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${travel['start_date']} ~ ${travel['end_date']}',
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              color: AppColors.textSecondary,
                            ),
                            onSelected: (value) async {
                              if (value == 'delete') {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('여행 삭제'),
                                    content: const Text(
                                      '이 여행과 모든 일기가 삭제됩니다.\n정말 삭제할까요?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('취소'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text(
                                          '삭제',
                                          style: TextStyle(
                                            color: AppColors.error,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (ok == true) {
                                  await TravelCreateService.deleteTravel(
                                    travel['id'],
                                  );
                                  if (!mounted) return;
                                  _refresh();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('여행이 삭제되었습니다'),
                                    ),
                                  );
                                }
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  '여행 삭제',
                                  style: TextStyle(color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          final createdTravel = await Navigator.push<Map<String, dynamic>>(
            context,
            MaterialPageRoute(builder: (_) => const TravelTypeSelectPage()),
          );

          if (!mounted) return;

          if (createdTravel != null) {
            _refresh();
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TravelDiaryListPage(travel: createdTravel),
              ),
            );
            if (!mounted) return;
            _refresh();
          }
        },
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}

// ==============================
// 🔒 여행 완료 배지
// ==============================
class _FinishedBadge extends StatelessWidget {
  const _FinishedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        '여행완료',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
