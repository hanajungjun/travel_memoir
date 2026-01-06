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
      // 🎨 전체 배경색을 약간 회색으로 설정 (카드가 돋보이게)
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        centerTitle: true,
        title: Text('여행 기록', style: AppTextStyles.sectionTitle),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const TravelInfoListSkeleton();
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('아직 여행이 없어요', style: AppTextStyles.bodyMuted),
            );
          }

          final travels = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: travels.length,
            // ✂️ 구분선 대신 간격을 두어 카드 느낌을 살림
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final travel = travels[index];

              return _SwipeDeleteItem(
                travel: travel,
                onDelete: () async {
                  await TravelCreateService.deleteTravel(travel['id']);
                  if (!mounted) return;
                  _refresh();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('여행이 삭제되었습니다')));
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
      floatingActionButton: SizedBox(
        width: 60,
        height: 60,
        child: FloatingActionButton(
          elevation: 8, // 그림자를 조금 더 깊게
          backgroundColor: AppColors.travelingBlue,
          // 🎨 카드와 어울리는 둥근 사각형 모양으로 변경
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
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
          child: const Icon(Icons.add, color: Colors.white, size: 32),
        ),
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
        motion: const StretchMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            borderRadius: BorderRadius.circular(20), // 카드 곡률과 맞춤
          ),
        ],
      ),
      child: _TravelListItem(travel: travel, onTap: onTap),
    );
  }
}

// =====================================================
// 🧳 리뉴얼된 여행 카드 UI
// =====================================================
class _TravelListItem extends StatelessWidget {
  final Map<String, dynamic> travel;
  final VoidCallback onTap;

  const _TravelListItem({required this.travel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDomestic = travel['travel_type'] == 'domestic';

    // 🏷️ 제목 (스크린샷처럼 영문명 포함 가능)
    // 🌐 한국어 설정 여부 확인
    final bool isKo =
        View.of(context).platformDispatcher.locale.languageCode == 'ko';

    // ✅ 다국어 컬럼 반영
    final String title =
        travel['region_name'] ??
        (isKo ? travel['country_name_ko'] : travel['country_name_en']) ??
        '';
    final String engTitle =
        travel['region_eng'] ?? travel['country_code'] ?? '';

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

        // 🎨 상태별 색상 (스크린샷 느낌)
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
              // ☁️ 부드러운 카드 그림자
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
                            // 💊 국/내외 뱃지
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
                                isDomestic ? '국내' : '해외',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: badgeColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // 📍 지역명
                            Expanded(
                              child: Text(
                                engTitle.isNotEmpty
                                    ? '$title, $engTitle'
                                    : title,
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
                        // 📅 여행 기간
                        Text(
                          '$start ~ $end',
                          style: AppTextStyles.bodyMuted.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  // 📊 작성 진행률
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                          children: [
                            TextSpan(
                              text: '$written',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: completed ? Colors.grey : Colors.black,
                              ),
                            ),
                            TextSpan(text: ' / $totalDays 작성'),
                          ],
                        ),
                      ),
                    ],
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
