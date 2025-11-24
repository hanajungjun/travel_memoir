import 'package:flutter/material.dart';
import 'package:daily_word_admin/models/daily_word.dart';

class HistoryDetailPage extends StatelessWidget {
  final DailyWord word;

  const HistoryDetailPage({super.key, required this.word});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("기록 상세 (${word.date})")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 날짜 + timestamp
            Text(
              "${word.date} (${word.updatedAt})",
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),

            const SizedBox(height: 16),

            // 제목
            Text(
              word.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 24),

            // 이미지 (🔥 timestamp 기반 파일명 그대로 사용)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(word.imageUrl, fit: BoxFit.contain),
            ),

            const SizedBox(height: 24),

            // 설명
            Text(word.description, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
