import 'package:flutter/material.dart';
import '../services/daily_word_service.dart';
import '../models/daily_word.dart';
import 'history_detail_page.dart';
import '../utils/date_formatter.dart'; // 🔥 포맷 가져오기

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final dailyWordService = DailyWordService();
  late Future<List<Map<String, dynamic>>> historyFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      historyFuture = dailyWordService.fetchHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("히스토리")),
      body: FutureBuilder(
        future: historyFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = snapshot.data!;

          if (list.isEmpty) {
            return const Center(child: Text("히스토리가 없습니다"));
          }

          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final item = list[i];
              final updatedAt = DateTime.parse(item['updated_at']);

              return ListTile(
                dense: true,
                title: Text(item['title'] ?? ''),
                subtitle: Text(
                  formatDate(updatedAt), // 🔥 포맷 사용
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right),

                onTap: () async {
                  final changed = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          HistoryDetailPage(word: DailyWord.fromMap(item)),
                    ),
                  );

                  if (changed == true) _reload();
                },
              );
            },
          );
        },
      ),
    );
  }
}
