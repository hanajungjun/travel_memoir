import 'package:flutter/material.dart';

import 'package:travel_memoir/services/travel_service.dart';
import 'package:travel_memoir/services/travel_list_service.dart';
import 'package:travel_memoir/services/travel_day_service.dart';

import 'package:travel_memoir/features/travel_diary/pages/travel_diary_list_page.dart';

import 'package:travel_memoir/core/utils/date_utils.dart';
import 'package:travel_memoir/core/widgets/travel_map_pager.dart';

class HomePage extends StatelessWidget {
  final VoidCallback onGoToTravel;

  const HomePage({super.key, required this.onGoToTravel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Travel Memoir'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📅 오늘 날짜
            Text(
              DateUtilsHelper.todayText(),
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),

            const SizedBox(height: 16),

            // ✍️ 오늘의 일기
            const Text(
              '오늘의 일기',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  final travel = await TravelService.getTodayTravel();

                  if (travel == null) {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('여행이 없어요'),
                        content: const Text('오늘은 여행 중이 아니에요.\n여행을 추가할까요?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('취소'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              onGoToTravel();
                            },
                            child: const Text('여행 추가'),
                          ),
                        ],
                      ),
                    );
                    return;
                  }

                  final diary = await TravelDayService.getDiaryByDate(
                    travelId: travel['id'],
                    date: DateTime.now(),
                  );

                  final hasDiary =
                      diary != null &&
                      (diary['text'] ?? '').toString().isNotEmpty;

                  if (hasDiary) {
                    final action = await showDialog<String>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('오늘의 일기가 있어요'),
                        content: const Text('이미 작성한 일기가 있습니다.\n어떻게 할까요?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, 'edit'),
                            child: const Text('수정하기'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, 'new'),
                            child: const Text('새로 작성하기'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, null),
                            child: const Text('취소'),
                          ),
                        ],
                      ),
                    );

                    if (action == null) return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TravelDiaryListPage(travel: travel),
                    ),
                  );
                },
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: _getTodayDiaryStatus(),
                  builder: (context, snapshot) {
                    final hasDiary =
                        snapshot.data != null &&
                        (snapshot.data?['text'] ?? '').toString().isNotEmpty;

                    return Text(
                      hasDiary ? '✅ 오늘 일기 작성됨' : '✍️ 오늘 일기 쓰기',
                      style: const TextStyle(fontSize: 16),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 40),

            // 🧳 최근 여행
            const Text(
              '최근 여행',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            FutureBuilder<Map<String, dynamic>?>(
              future: _getRecentTravel(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final travel = snapshot.data;

                if (travel == null) {
                  return _emptyRecentTravel();
                }

                final bool isOngoing = _isOngoing(
                  travel['start_date'],
                  travel['end_date'],
                );

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TravelDiaryListPage(travel: travel),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isOngoing)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '여행중',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Text(
                          '${travel['city']} 여행',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${travel['start_date']} ~ ${travel['end_date']}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 40),

            // 🗺️ 여행 지도 (스와이프)
            const TravelMapPager(),
          ],
        ),
      ),
    );
  }

  // ===== helpers =====

  static Future<Map<String, dynamic>?> _getTodayDiaryStatus() async {
    final travel = await TravelService.getTodayTravel();
    if (travel == null) return null;

    return await TravelDayService.getDiaryByDate(
      travelId: travel['id'],
      date: DateTime.now(),
    );
  }

  static Future<Map<String, dynamic>?> _getRecentTravel() async {
    final todayTravel = await TravelService.getTodayTravel();
    if (todayTravel != null) return todayTravel;

    final travels = await TravelListService.getTravels();
    if (travels.isEmpty) return null;

    return travels.first;
  }

  static bool _isOngoing(String start, String end) {
    final today = DateTime.now();
    final s = DateTime.parse(start);
    final e = DateTime.parse(end); // ✅ 여기
    return !today.isBefore(s) && !today.isAfter(e);
  }

  Widget _emptyRecentTravel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text('아직 여행이 없어요', style: TextStyle(color: Colors.grey)),
    );
  }
}
