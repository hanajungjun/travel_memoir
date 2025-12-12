import 'package:flutter/material.dart';
import '../../../services/travel_day_service.dart';
import '../../../core/utils/date_utils.dart';

class TravelDayPage extends StatelessWidget {
  final String travelId;
  final String city;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime date;

  const TravelDayPage({
    super.key,
    required this.travelId,
    required this.city,
    required this.startDate,
    required this.endDate,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final dayNumber = DateUtilsHelper.calculateDayNumber(
      startDate: startDate,
      currentDate: date,
    );

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        centerTitle: true,
        title: Column(
          children: [
            Text(
              '${date.month}.${date.day}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 2),
            Text(
              '$city 여행 · DAY $dayNumber',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🧳 여행 기간
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_fmt(startDate)} ~ ${_fmt(endDate)}',
                style: const TextStyle(color: Colors.grey),
              ),
            ),

            const SizedBox(height: 16),

            // ✍️ 일기 입력
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const TextField(
                  maxLines: null,
                  expands: true,
                  decoration: InputDecoration(
                    hintText: '오늘의 여행 기록을 남겨보세요 ✍️',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 💾 저장 버튼
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: 저장 로직
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('오늘 기록이 저장됐어요 ✨')),
                  );
                },
                child: const Text('저장', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}
