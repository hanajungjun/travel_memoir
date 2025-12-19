import 'package:supabase_flutter/supabase_flutter.dart';

class TravelListService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getTravels() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return [];
    }

    final res = await _supabase
        .from('travels')
        .select()
        .order('start_date', ascending: false);

    return List<Map<String, dynamic>>.from(res);
  }
}
