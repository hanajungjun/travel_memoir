import 'package:supabase_flutter/supabase_flutter.dart';

class TravelCreateService {
  static final _supabase = Supabase.instance.client;

  static Future<String> createDomesticTravel({
    required String city,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final res = await _supabase
        .from('travels')
        .insert({
          // user_id ❌ 완전 제거
          'country': 'KR',
          'city': city,
          'start_date': startDate.toIso8601String().substring(0, 10),
          'end_date': endDate.toIso8601String().substring(0, 10),
        })
        .select('id')
        .single();

    return res['id'] as String;
  }
}
