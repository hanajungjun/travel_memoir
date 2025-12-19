import 'package:supabase_flutter/supabase_flutter.dart';

class TravelCreateService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<Map<String, dynamic>> createDomesticTravel({
    required String userId, // 🔥 로그인한 유저 ID
    required String city,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final res = await _supabase
        .from('travels')
        .insert({
          'user_id': userId,
          'country': 'KR',
          'city': city,
          'start_date': startDate.toIso8601String().substring(0, 10),
          'end_date': endDate.toIso8601String().substring(0, 10),
        })
        .select()
        .single();

    return res;
  }

  static Future<void> deleteTravel(String travelId) async {
    await _supabase.from('travels').delete().eq('id', travelId);
  }
}
