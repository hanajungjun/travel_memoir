import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class OverseasTravelService {
  static final _supabase = Supabase.instance.client;

  /// 🌍 해외 여행 목록 (국가 코드 포함)
  static Future<List<Map<String, dynamic>>> getOverseasTravels({
    required String userId,
  }) async {
    debugPrint('🌍 [OVERSEAS] load travels (user=$userId)');

    final rows = await _supabase
        .from('travels')
        // ✅ country_name 대신 다국어 컬럼 2개를 모두 가져옵니다.
        .select('id, country_name_ko, country_name_en, country_code')
        .eq('user_id', userId)
        .eq('travel_type', 'overseas');

    return List<Map<String, dynamic>>.from(rows);
  }

  /// 📍 국가/도시 이름 → 좌표 (Edge Function)
  static Future<Map<String, dynamic>?> geocode({required String query}) async {
    debugPrint('🌍 [OVERSEAS][GEOCODE] query=$query');

    final res = await _supabase.functions.invoke(
      'geocode_city',
      body: {'query': query},
    );

    debugPrint('🌍 [OVERSEAS][GEOCODE] res=${res.data}');

    if (res.data == null) return null;
    return Map<String, dynamic>.from(res.data);
  }
}
