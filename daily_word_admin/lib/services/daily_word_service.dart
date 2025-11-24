import 'package:supabase_flutter/supabase_flutter.dart';

class DailyWordService {
  final supabase = Supabase.instance.client;

  Future<void> saveDailyWord({
    required String date,
    required String title,
    required String description,
    required String imageUrl,
  }) async {
    await supabase.from('daily_words').insert({
      'date': date,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> fetchHistory() async {
    return await supabase
        .from('daily_words')
        .select()
        .order('updated_at', ascending: false);
  }

  Future<void> deleteWord(String id) async {
    await supabase.from('daily_words').delete().eq('id', id);
  }

  Future<void> updateWord(String id, Map<String, dynamic> data) async {
    await supabase.from('daily_words').update(data).eq('id', id);
  }
}
