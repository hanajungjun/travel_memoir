import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StampService {
  final _client = Supabase.instance.client;

  // ===============================
  // 유저 스탬프 데이터 조회
  // ===============================
  Future<Map<String, dynamic>?> getStampData(String userId) async {
    return await _client
        .from('users')
        .select(
          'daily_stamps, vip_stamps, paid_stamps, is_vip, last_coin_reset_date, ad_reward_count, ad_reward_date',
        )
        .eq('auth_uid', userId)
        .maybeSingle();
  }

  // ===============================
  // ⭐ [유지] reward_config에서 문구와 금액 관리
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
  // 데일리 로그인 보상 알림 (하루 1회 제한)
  // ===============================
  Future<Map<String, dynamic>?> checkAndGrantDailyReward(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // 1. 이미 오늘 팝업을 보여줬는지 로컬(폰) 기록 확인
      final String? lastShown = prefs.getString('last_reward_popup_seen');
      if (lastShown == todayStr) return null;

      // 2. 유저 정보와 보상 설정(reward_config) 가져오기
      final userData = await getStampData(userId);
      final reward = await getRewardConfig('daily_login'); // 테이블에서 가져옴!

      if (userData == null || reward == null) return null;

      final String? lastResetDateStr = userData['last_coin_reset_date']
          ?.toString();

      // 3. 서버가 오늘 날짜로 리셋을 완료했다면 팝업 데이터 구성
      if (lastResetDateStr != null && todayStr == lastResetDateStr) {
        // ✅ 오늘 팝업 보여줌 기록 저장
        await prefs.setString('last_reward_popup_seen', todayStr);

        // reward_config의 데이터를 팝업으로 넘겨줌
        final result = Map<String, dynamic>.from(reward);
        result['daily_stamps'] = userData['daily_stamps'];
        result['vip_stamps'] = userData['vip_stamps'];
        result['paid_stamps'] = userData['paid_stamps'];

        return result;
      }
      return null;
    } catch (e) {
      debugPrint('❌ daily reward error: $e');
      return null;
    }
  }

  // ===============================
  // 스탬프 소모 로직 (VIP 우선 소모)
  // ===============================
  Future<bool> useStamp(String userId, String userSelectedType) async {
    try {
      final userData = await getStampData(userId);
      if (userData == null) return false;

      final bool isVip = userData['is_vip'] ?? false;
      int vipStamps = (userData['vip_stamps'] ?? 0).toInt();

      String targetCol = (isVip && vipStamps > 0)
          ? 'vip_stamps'
          : userSelectedType;
      int currentCount = (userData[targetCol] ?? 0).toInt();

      if (currentCount <= 0) return false;

      await _client
          .from('users')
          .update({targetCol: currentCount - 1})
          .eq('auth_uid', userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ===============================
  // 광고 보상 실제 지급
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

      if (lastDate != todayStr) count = 0;
      if (count >= dailyLimit) return null;

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
  // 수동 스탬프 추가 (무료 지급용)
  // ===============================
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
  // 광고 보상 상태 조회
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
      if (lastDate != todayStr) usedCount = 0;

      return {'used': usedCount, 'limit': dailyLimit};
    } catch (e) {
      debugPrint('❌ getAdRewardStatus error: $e');
      return null;
    }
  }
}
