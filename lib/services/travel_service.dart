import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class TravelService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<Map<String, dynamic>?> getTodayTravel() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final now = DateTime.now();
    // 🎯 오늘 날짜의 시작(00:00:00)과 끝(23:59:59)을 설정합니다.
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
      0,
      0,
      0,
    ).toIso8601String();
    final todayEnd = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
    ).toIso8601String();

    try {
      final List<dynamic> res = await _supabase
          .from('travels')
          .select()
          .eq('user_id', user.id)
          .eq('is_completed', false)
          // 🎯 수정된 조건: 시작일이 오늘 밤보다 전이고, 종료일이 오늘 아침보다 뒤인 것
          .lte('start_date', todayEnd) // 시작일 <= 2026-02-12 23:59:59
          .gte('end_date', todayStart) // 종료일 >= 2026-02-12 00:00:00
          .order('created_at', ascending: false)
          .limit(1);

      if (res.isEmpty) {
        debugPrint("📅 [TravelService] 오늘 진행 중인 여행 없음");
        return null;
      }

      return res.first as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ getTodayTravel Error: $e');
      return null;
    }
  }
}
