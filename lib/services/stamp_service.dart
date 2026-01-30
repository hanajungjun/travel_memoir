import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class StampService {
  final _client = Supabase.instance.client;

  static bool hasShownPopup = false;

  // ===============================
  // 유저 스탬프 데이터
  // ===============================
  Future<Map<String, dynamic>?> getStampData(String userId) async {
    return await _client
        .from('users')
        .select(
          'daily_stamps, paid_stamps, last_coin_reset_date, ad_reward_count, ad_reward_date',
        )
        .eq('auth_uid', userId)
        .maybeSingle();
  }

  // ===============================
  // reward_config 조회
  // ===============================
  Future<Map<String, dynamic>?> getRewardConfig(String type) async {
    return await _client
        .from('reward_config')
        .select()
        .eq('type', type)
        .eq('is_active', true)
        .maybeSingle();
  }

  // ===============================
  // 데일리 로그인 보상
  // ===============================
  Future<Map<String, dynamic>?> checkAndGrantDailyReward(String userId) async {
    if (hasShownPopup) return null;

    try {
      final userData = await getStampData(userId);
      if (userData == null) return null;

      final reward = await getRewardConfig('daily_login');
      if (reward == null) return null;

      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final String? lastResetDateStr = userData['last_coin_reset_date'];

      if (lastResetDateStr == null || todayStr != lastResetDateStr.toString()) {
        final int rewardAmount = (reward['reward_amount'] ?? 0).toInt();
        final int currentDaily = (userData['daily_stamps'] ?? 0).toInt();

        await _client
            .from('users')
            .update({
              'daily_stamps': currentDaily + rewardAmount,
              'last_coin_reset_date': todayStr,
            })
            .eq('auth_uid', userId);

        hasShownPopup = true;
        return reward;
      }

      return null;
    } catch (e) {
      debugPrint('❌ daily reward error: $e');
      return null;
    }
  }

  // ===============================
  // ⭐ 광고 보상 실제 지급 (추가된 부분)
  // ===============================
  Future<Map<String, dynamic>?> grantAdReward(String userId) async {
    try {
      final userData = await getStampData(userId);
      if (userData == null) return null;

      final reward = await getRewardConfig('ad_watch_stamp');
      if (reward == null) return null;

      final int rewardAmount = (reward['reward_amount'] ?? 0).toInt();
      final int dailyLimit = (reward['daily_limit'] ?? 0).toInt();

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final String? lastDate = userData['ad_reward_date']?.toString();
      int count = (userData['ad_reward_count'] ?? 0).toInt();

      // 날짜 바뀌면 리셋
      if (lastDate != todayStr) {
        count = 0;
      }

      // 하루 제한 초과
      if (count >= dailyLimit) {
        return null;
      }

      final int currentDaily = (userData['daily_stamps'] ?? 0).toInt();

      await _client
          .from('users')
          .update({
            'daily_stamps': currentDaily + rewardAmount,
            'ad_reward_count': count + 1,
            'ad_reward_date': todayStr,
          })
          .eq('auth_uid', userId);

      return reward;
    } catch (e) {
      debugPrint('❌ ad reward error: $e');
      return null;
    }
  }

  // ===============================
  // 기존 로직 유지
  // ===============================
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

  Future<void> addFreeStamp(String userId, int amount) async {
    final userData = await getStampData(userId);
    if (userData == null) return;

    int currentDaily = (userData['daily_stamps'] ?? 0).toInt();
    await _client
        .from('users')
        .update({'daily_stamps': currentDaily + amount})
        .eq('auth_uid', userId);
  }

  // ===============================
  // ✅ 광고 보상 상태 조회 (CoinShop용)
  // ===============================
  Future<Map<String, int>?> getAdRewardStatus(String userId) async {
    try {
      final userData = await getStampData(userId);
      if (userData == null) return null;

      final reward = await getRewardConfig('ad_watch_stamp');
      if (reward == null) return null;

      final int dailyLimit = (reward['daily_limit'] ?? 0).toInt();

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final String? lastDate = userData['ad_reward_date']?.toString();

      int usedCount = (userData['ad_reward_count'] ?? 0).toInt();

      // 날짜가 다르면 0으로 리셋된 상태로 보여줌 (UX용)
      if (lastDate != todayStr) {
        usedCount = 0;
      }

      return {'used': usedCount, 'limit': dailyLimit};
    } catch (e) {
      debugPrint('❌ getAdRewardStatus error: $e');
      return null;
    }
  }
}
