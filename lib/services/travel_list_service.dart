import 'package:supabase_flutter/supabase_flutter.dart';

class TravelListService {
  static final _supabase = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getTravels() async {
    final res = await _supabase
        .from('travels')
        .select()
        // user_id 조건 ❌ 제거
        .order('start_date', ascending: false);

    return List<Map<String, dynamic>>.from(res);
  }
}
