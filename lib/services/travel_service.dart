import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class TravelService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<Map<String, dynamic>?> getTodayTravel() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    // ✅ 오늘 날짜 (로컬 시간 기준 YYYY-MM-DD)
    final now = DateTime.now();
    final today =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    try {
      // 🎯 maybeSingle() 대신 리스트로 가져오기 (데이터가 2개 이상일 때 에러 방지)
      final List<dynamic> res = await _supabase
          .from('travels')
          .select()
          .eq('user_id', user.id)
          .eq('is_completed', false)
          .lte('start_date', today)
          .gte('end_date', today)
          .order('created_at', ascending: false) // 최신 생성 순
          .limit(1); // 무조건 1개만 가져오기

      if (res.isEmpty) {
        debugPrint("📅 [TravelService] 오늘 진행 중인 여행 없음 ($today)");
        return null;
      }

      debugPrint(
        "✅ [TravelService] 오늘 여행 발견: ${res.first['region_name'] ?? res.first['country_code']}",
      );
      return res.first as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ getTodayTravel Error: $e');
      return null;
    }
  }
}
