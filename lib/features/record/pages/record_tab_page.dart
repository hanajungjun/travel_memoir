import 'package:flutter/material.dart';
import 'package:travel_memoir/services/travel_list_service.dart';
import 'package:travel_memoir/core/utils/date_utils.dart';
import 'package:travel_memoir/features/travel_diary/pages/travel_diary_list_page.dart';

class RecordTabPage extends StatefulWidget {
  const RecordTabPage({super.key});

  @override
  State<RecordTabPage> createState() => _RecordTabPageState();
}

class _RecordTabPageState extends State<RecordTabPage> {
  final PageController _controller = PageController();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = TravelListService.getTravels();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final travels = snapshot.data!;
          final finished = travels.where((t) {
            final end = DateTime.parse(t['end_date']);
            return DateTime.now().isAfter(end);
          }).toList();

          if (finished.isEmpty) {
            return const Center(child: Text('아직 지난 여행이 없어요'));
          }

          finished.sort((a, b) => b['end_date'].compareTo(a['end_date']));
          final lastTravel = finished.first;

          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // 📌 지도 카드(1번 페이지)에서
              // 위로 더 끌어올리면 → 0번 카드로 복귀
              if (notification is OverscrollNotification) {
                if (_controller.page?.round() == 1 &&
                    notification.overscroll > 0) {
                  _controller.animateToPage(
                    0,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                  );
                  return true;
                }
              }
              return false;
            },
            child: PageView(
              controller: _controller,
              scrollDirection: Axis.vertical,
              physics: const BouncingScrollPhysics(),
              children: [
                // ==========================
                // 0️⃣ 감성 요약 카드
                // ==========================
                _SummaryHeroCard(
                  travel: lastTravel,
                  totalCount: finished.length,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TravelDiaryListPage(travel: lastTravel),
                      ),
                    );
                  },
                ),

                // ==========================
                // 1️⃣ 여행 지도 카드
                // ==========================
                _MapPreviewCard(),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ==============================
// 🧠 감성 요약 카드 (0번)
// ==============================
class _SummaryHeroCard extends StatelessWidget {
  final Map<String, dynamic> travel;
  final int totalCount;
  final VoidCallback onTap;

  const _SummaryHeroCard({
    required this.travel,
    required this.totalCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final end = DateTime.parse(travel['end_date']);

    return SafeArea(
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),

              const Text(
                '기억을 다시 꺼내볼까요?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 24),

              Text('지금까지의 여행 · 총 $totalCount번'),

              const SizedBox(height: 12),

              Text('마지막으로 떠났던 날 · ${DateUtilsHelper.formatYMD(end)}'),
              Text(
                DateUtilsHelper.memoryTimeAgo(end),
                style: const TextStyle(color: Colors.grey),
              ),

              const Spacer(),

              const Center(
                child: Column(
                  children: [
                    Icon(Icons.keyboard_arrow_up, size: 28),
                    SizedBox(height: 4),
                    Text('여행 지도 보기', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================
// 🗺️ 여행 지도 카드 (1번)
// ==============================
class _MapPreviewCard extends StatelessWidget {
  const _MapPreviewCard();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Text(
              '여행 지도',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              '지도로 여행의 흔적을 볼 수 있어요',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),

            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(child: Text('🗺️ 지도 준비 중')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
