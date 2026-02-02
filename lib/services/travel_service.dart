import 'package:supabase_flutter/supabase_flutter.dart';

class TravelService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<Map<String, dynamic>?> getTodayTravel() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    // ✅ 오늘 날짜 (YYYY-MM-DD 형식)
    final today = DateTime.now().toIso8601String().substring(0, 10);

    try {
      final travel = await _supabase
          .from('travels')
          .select()
          .eq('user_id', user.id)
          .eq('is_completed', false)
          .lte('start_date', today)
          .gte('end_date', today)
          .order('created_at', ascending: false)
          .maybeSingle();

      return travel;
    } catch (e) {
      print('❌ getTodayTravel Error: $e');
      return null;
    }
  }
}
