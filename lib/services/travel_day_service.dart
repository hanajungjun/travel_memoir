import 'package:supabase_flutter/supabase_flutter.dart';

class TravelDayService {
  static final _supabase = Supabase.instance.client;

  static Future<Map<String, dynamic>> getOrCreateTodayDay({
    required String travelId,
  }) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final existing = await _supabase
        .from('travel_days')
        .select()
        .eq('travel_id', travelId)
        .eq('date', today)
        .maybeSingle();

    if (existing != null) {
      return existing;
    }

    final inserted = await _supabase
        .from('travel_days')
        .insert({'travel_id': travelId, 'date': today, 'day_index': 1})
        .select()
        .single();

    return inserted;
  }

  /// ✅ 오늘 일기 저장
  static Future<void> updateDiary({
    required String dayId,
    required String text,
  }) async {
    await _supabase.from('travel_days').update({'text': text}).eq('id', dayId);
  }
}
