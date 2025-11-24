import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/daily_word.dart';

class DailyWordService {
  final supabase = Supabase.instance.client;

  /// 항상 INSERT-only (업데이트 없음)
  Future<void> saveDailyWord(DailyWord word) async {
    final normalizedDate = DailyWord.normalizeDate(word.date);

    await supabase.from('daily_words').insert({
      ...word.toInsertMap(),
      'date': normalizedDate,
    });
  }

  /// 특정 날짜의 최신(updated_at) 1개만 불러오기
  Future<DailyWord?> getDailyWord(String date) async {
    final normalizedDate = DailyWord.normalizeDate(date);

    final data = await supabase
        .from('daily_words')
        .select()
        .eq('date', normalizedDate)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (data == null) return null;
    return DailyWord.fromMap(data);
  }

  /// 전체 리스트 최신(updated_at) 순 정렬
  Future<List<DailyWord>> getAllWords() async {
    final result = await supabase
        .from('daily_words')
        .select()
        .order('updated_at', ascending: false);

    return result.map((row) => DailyWord.fromMap(row)).toList();
  }
}
