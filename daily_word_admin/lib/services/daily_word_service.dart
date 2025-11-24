import 'package:supabase_flutter/supabase_flutter.dart';

class DailyWordService {
  final supabase = Supabase.instance.client;

  /// 최신순 10개 히스토리 불러오기
  Future<List<Map<String, dynamic>>> fetchHistory() async {
    final data = await supabase
        .from('daily_words')
        .select()
        .order('updated_at', ascending: false)
        .limit(10);

    return List<Map<String, dynamic>>.from(data);
  }

  /// 특정 날짜 데이터 1개 불러오기
  Future<Map<String, dynamic>?> fetchByDate(String date) async {
    final data = await supabase
        .from('daily_words')
        .select()
        .eq('date', date)
        .order('updated_at', ascending: false)
        .limit(1);

    if (data.isEmpty) return null;
    return data.first;
  }

  /// DB 저장 (업서트)
  Future<void> saveDailyWord({
    required String date,
    required String title,
    required String description,
    required String imageUrl,
  }) async {
    await supabase.from('daily_words').upsert({
      'date': date,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
