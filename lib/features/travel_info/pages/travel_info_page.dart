import 'package:flutter/material.dart';

import 'package:travel_memoir/services/travel_list_service.dart';
import 'package:travel_memoir/services/travel_create_service.dart';
import 'package:travel_memoir/services/travel_day_service.dart';

import 'package:travel_memoir/features/travel_diary/pages/travel_diary_list_page.dart';
import 'package:travel_memoir/features/travel_info/pages/travel_type_select_page.dart';

class TravelInfoPage extends StatefulWidget {
  const TravelInfoPage({super.key});

  @override
  State<TravelInfoPage> createState() => _TravelInfoPageState();
}

class _TravelInfoPageState extends State<TravelInfoPage> {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 여행'), elevation: 0),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final travels = snapshot.data ?? [];
          if (travels.isEmpty) {
            return const Center(
              child: Text('아직 여행이 없어요', style: TextStyle(color: Colors.grey)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: travels.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final travel = travels[index];

              final startDate = DateTime.parse(travel['start_date']);
              final endDate = DateTime.parse(travel['end_date']);
              final totalDays = endDate.difference(startDate).inDays + 1;

              final isFinished = DateTime.now().isAfter(endDate);

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    // 텍스트 영역
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TravelDiaryListPage(travel: travel),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 도시 + 여행완료 배지
                            Row(
                              children: [
                                Text(
                                  travel['city'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (isFinished) const _FinishedBadge(),
                              ],
                            ),

                            const SizedBox(height: 4),

                            // ✍️ 기록 상태 (n / total)
                            FutureBuilder<int>(
                              future: TravelDayService.getWrittenDayCount(
                                travelId: travel['id'],
                              ),
                              builder: (context, snapshot) {
                                final written = snapshot.data ?? 0;
                                return Text(
                                  '$written / $totalDays일 작성',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 2),

                            // 날짜
                            Text(
                              '${travel['start_date']} ~ ${travel['end_date']}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ⋮ 메뉴
                    PopupMenuButton<String>(
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
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text(
                                    '삭제',
                                    style: TextStyle(color: Colors.red),
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
                              const SnackBar(content: Text('여행이 삭제되었습니다')),
                            );
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            '여행 삭제',
                            style: TextStyle(color: Colors.red),
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

      // ➕ 여행 추가
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TravelTypeSelectPage()),
          );
          _refresh();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ==============================
// 🧳 여행완료 배지
// ==============================
class _FinishedBadge extends StatelessWidget {
  const _FinishedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        '여행완료',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
        ),
      ),
    );
  }
}
