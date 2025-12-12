import 'package:flutter/material.dart';

import '../../../services/travel_service.dart';
import '../../travel_day/pages/travel_day_page.dart';
import '../../../core/utils/date_utils.dart';

class HomePage extends StatelessWidget {
  final VoidCallback onGoToTravel;

  const HomePage({super.key, required this.onGoToTravel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Travel Memoir'), elevation: 0),
      body: Padding(
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

                  // ❌ 오늘 여행 없음 → 여행 추가로 이동
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
                              onGoToTravel(); // ⭐ 여행 탭으로 이동
                            },
                            child: const Text('여행 추가'),
                          ),
                        ],
                      ),
                    );
                    return;
                  }

                  // ✅ 오늘 여행 있음 → TravelDayPage가 내부에서 오늘 day 생성/로드함
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TravelDayPage(
                        travelId: travel['id'],
                        city: travel['city'],
                        startDate: DateTime.parse(travel['start_date']),
                        endDate: DateTime.parse(travel['end_date']),
                        date: DateTime.now(),
                      ),
                    ),
                  );
                },
                child: const Text(
                  '✍️ 오늘 일기 쓰기',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // 🧳 최근 여행 (더미)
            const Text(
              '최근 여행',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '최근 여행이 여기에 표시됩니다.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
