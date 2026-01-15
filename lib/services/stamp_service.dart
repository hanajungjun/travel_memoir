import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

class StampService {
  final _client = Supabase.instance.client;

  // ✨ 앱이 켜져 있는 동안 딱 한 번만 팝업을 띄우기 위한 깃발
  static bool hasShownPopup = false;

  // ✨ 유저 데이터 조회
  Future<Map<String, dynamic>?> getStampData(String userId) async {
    return await _client
        .from('users')
        .select('daily_stamps, paid_stamps, last_coin_reset_date')
        .eq('auth_uid', userId)
        .maybeSingle();
  }

  // ✨ [유일한 지급 통로] 하루 한 번 +5코인 누적 지급
  Future<bool> checkAndGrantDailyReward(String userId) async {
    if (hasShownPopup) return false;

    try {
      print("🔍 [StampService] 보상 수사 시작...");
      final userData = await getStampData(userId);
      if (userData == null) return false;

      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final String? lastResetDateStr = userData['last_coin_reset_date'];

      print("🔍 [StampService] 오늘: $todayStr / DB값: $lastResetDateStr");

      // 날짜가 다르거나 없으면 지급
      bool isNewDay = false;
      if (lastResetDateStr == null || lastResetDateStr == "") {
        isNewDay = true;
      } else {
        if (todayStr != lastResetDateStr.substring(0, 10)) {
          isNewDay = true;
        }
      }

      if (isNewDay) {
        // ✨ 누적 방식: 현재 개수(1) + 5 = 6!
        int currentDaily = (userData['daily_stamps'] ?? 0).toInt();
        int nextDaily = currentDaily + 5;

        print("🚨 [StampService] 누적 업데이트 실행! $currentDaily -> $nextDaily");

        await _client
            .from('users')
            .update({
              'daily_stamps': nextDaily,
              'last_coin_reset_date': todayStr,
            })
            .eq('auth_uid', userId);

        hasShownPopup = true;
        return true;
      }
      return false;
    } catch (e) {
      print("❌ [StampService] 에러 발생: $e");
      return false;
    }
  }

  // ✨ 도장 차감 (TravelDayPage 에러 방지용)
  Future<void> consumeStamp(
    String userId, {
    required bool isFree,
    required int currentCount,
  }) async {
    final col = isFree ? 'daily_stamps' : 'paid_stamps';
    await _client
        .from('users')
        .update({col: currentCount - 1})
        .eq('auth_uid', userId);
  }

  // ✨ 광고 보상 추가 (TravelDayPage 에러 방지용)
  Future<void> addFreeStamp(String userId, int currentCount) async {
    await _client
        .from('users')
        .update({'daily_stamps': currentCount + 1})
        .eq('auth_uid', userId);
  }
}
