import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

class StampService {
  final _client = Supabase.instance.client;

  static bool hasShownPopup = false;

  Future<Map<String, dynamic>?> getStampData(String userId) async {
    return await _client
        .from('users')
        .select('daily_stamps, paid_stamps, last_coin_reset_date')
        .eq('auth_uid', userId)
        .maybeSingle();
  }

  // 일일 보상 체크 로직 (기존 유지)
  Future<bool> checkAndGrantDailyReward(String userId) async {
    if (hasShownPopup) return false;
    try {
      final userData = await getStampData(userId);
      if (userData == null) return false;

      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final String? lastResetDateStr = userData['last_coin_reset_date'];

      if (lastResetDateStr == null ||
          todayStr != lastResetDateStr.substring(0, 10)) {
        int currentDaily = (userData['daily_stamps'] ?? 0).toInt();
        await _client
            .from('users')
            .update({
              'daily_stamps': currentDaily + 5,
              'last_coin_reset_date': todayStr,
            })
            .eq('auth_uid', userId);

        hasShownPopup = true;
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ✅ [에러 해결] consumeStamp -> useStamp로 이름 변경 및 로직 개선
  Future<void> useStamp(String userId, bool isPaid) async {
    final userData = await getStampData(userId);
    if (userData == null) return;

    final col = isPaid ? 'paid_stamps' : 'daily_stamps';
    int currentCount = (userData[col] ?? 0).toInt();

    await _client
        .from('users')
        .update({col: currentCount - 1})
        .eq('auth_uid', userId);
  }

  // ✅ [에러 해결] 파라미터를 amount(수량)로 변경하여 더 유연하게 수정
  Future<void> addFreeStamp(String userId, int amount) async {
    final userData = await getStampData(userId);
    if (userData == null) return;

    int currentDaily = (userData['daily_stamps'] ?? 0).toInt();
    await _client
        .from('users')
        .update({'daily_stamps': currentDaily + amount})
        .eq('auth_uid', userId);
  }
}
