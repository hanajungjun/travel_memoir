import 'package:flutter/material.dart';
import '../models/daily_word.dart';
import '../services/daily_word_service.dart';
import 'edit_page.dart';
import '../utils/date_formatter.dart'; // 🔥 날짜 포맷 가져오기

class HistoryDetailPage extends StatelessWidget {
  final DailyWord word;

  const HistoryDetailPage({super.key, required this.word});

  @override
  Widget build(BuildContext context) {
    final dailyWordService = DailyWordService();

    return Scaffold(
      appBar: AppBar(
        // 🔥 제목 (formatted 날짜)
        title: Text("${word.title} (${formatDate(word.updatedAt)})"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final changed = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditPage(word: word)),
              );

              if (changed == true) {
                Navigator.pop(context, true);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () async {
              await dailyWordService.deleteWord(word.id);
              Navigator.pop(context, true);
            },
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(word.imageUrl, fit: BoxFit.contain),
            ),

            const SizedBox(height: 24),

            Text(
              word.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 24),

            Text(word.description, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
