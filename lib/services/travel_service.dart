import 'package:supabase_flutter/supabase_flutter.dart';

class TravelService {
  static final _supabase = Supabase.instance.client;

  static Future<Map<String, dynamic>?> getTodayTravel() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final travel = await _supabase
        .from('travels')
        .select()
        // user_id 조건 ❌ 제거
        .lte('start_date', today)
        .gte('end_date', today)
        .order('created_at', ascending: false)
        .maybeSingle();

    return travel;
  }
}
