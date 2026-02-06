import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_memoir/services/logger_service.dart'; // ✅ 로거 임포트

class StampService {
  final _client = Supabase.instance.client;
  final _logger = LoggerService(); // ✅ 로거 인스턴스

  Future<Map<String, dynamic>?> getStampData(String userId) async {
    return await _client
        .from('users')
        .select(
          'daily_stamps, vip_stamps, paid_stamps, is_vip, last_coin_reset_date, ad_reward_count, ad_reward_date',
        )
        .eq('auth_uid', userId)
        .maybeSingle();
  }

  Future<Map<String, dynamic>?> getRewardConfig(String type) async {
    return await _client
        .from('reward_config')
        .select()
        .eq('type', type)
        .eq('is_active', true)
        .maybeSingle();
  }

  Future<Map<String, dynamic>?> checkAndGrantDailyReward(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = await getStampData(userId);
      if (userData == null) return null;

      final bool isVip = userData['is_vip'] ?? false;
      final String rewardType = isVip ? 'daily_login_vip' : 'daily_login';
      final reward = await getRewardConfig(rewardType);

      if (reward == null) return null;

      final String? serverResetDate = userData['last_coin_reset_date']
          ?.toString();
      if (serverResetDate == null) return null;

      final String? lastSeenDate = prefs.getString(
        'last_reward_popup_seen_date',
      );

      if (lastSeenDate != serverResetDate) {
        await prefs.setString('last_reward_popup_seen_date', serverResetDate);
        final result = Map<String, dynamic>.from(reward);
        result['is_vip'] = isVip;
        result['daily_stamps'] = userData['daily_stamps'];
        result['vip_stamps'] = userData['vip_stamps'];
        result['paid_stamps'] = userData['paid_stamps'];
        return result;
      }
      return null;
    } catch (e) {
      _logger.error("❌ 데일리 리워드 에러: $e", tag: "STAMP_SERVICE");
      return null;
    }
  }

  // ✅ [수정 완료] 유저의 선택을 존중하여 해당 타입만 정확히 차감
  Future<bool> useStamp(String userId, String userSelectedType) async {
    try {
      _logger.log(
        "💰 스탬프 소모 시도 (요청 타입: $userSelectedType)",
        tag: "STAMP_PROCESS",
      );

      final userData = await getStampData(userId);
      if (userData == null) {
        _logger.error("❌ 스탬프 차감 실패: 유저 데이터 없음", tag: "STAMP_PROCESS");
        return false;
      }

      // 🎯 [핵심 변경] 서비스에서 멋대로 VIP를 체크하지 않고,
      // 전달받은 타입(daily, paid, vip) 뒤에 _stamps만 붙여서 컬럼을 결정합니다.
      String targetCol = "${userSelectedType}_stamps";
      int currentCount = (userData[targetCol] ?? 0).toInt();

      _logger.log(
        "🔍 최종 차감 대상 컬럼: $targetCol (현재 수량: $currentCount)",
        tag: "STAMP_PROCESS",
      );

      // 차감 전 수량 체크
      if (currentCount <= 0) {
        _logger.warn("⚠️ 차감 중단: $targetCol 수량이 부족함", tag: "STAMP_PROCESS");
        return false;
      }

      // 실제 DB 업데이트 실행
      final response = await _client
          .from('users')
          .update({targetCol: currentCount - 1})
          .eq('auth_uid', userId)
          .select();

      if (response.isNotEmpty) {
        _logger.log(
          "✅ 스탬프 DB 차감 성공 ($targetCol: $currentCount -> ${currentCount - 1})",
          tag: "STAMP_PROCESS",
        );
        return true;
      } else {
        _logger.error("❌ 스탬프 DB 차감 실패: 업데이트된 행이 없음", tag: "STAMP_PROCESS");
        return false;
      }
    } catch (e) {
      _logger.error("🔥 useStamp 치명적 에러: $e", tag: "STAMP_PROCESS");
      return false;
    }
  }

  Future<Map<String, dynamic>?> grantAdReward(String userId) async {
    try {
      final userData = await getStampData(userId);
      if (userData == null) return null;
      final reward = await getRewardConfig('ad_watch_stamp');
      if (reward == null) return null;

      final int rewardAmount = (reward['reward_amount'] ?? 0).toInt();
      final int dailyLimit = (reward['daily_limit'] ?? 0).toInt();
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      int count = (userData['ad_reward_count'] ?? 0).toInt();

      if (userData['ad_reward_date']?.toString() != todayStr) count = 0;
      if (count >= dailyLimit) return null;

      await _client
          .from('users')
          .update({
            'daily_stamps':
                (userData['daily_stamps'] ?? 0).toInt() + rewardAmount,
            'ad_reward_count': count + 1,
            'ad_reward_date': todayStr,
          })
          .eq('auth_uid', userId);
      return reward;
    } catch (e) {
      _logger.error("❌ 광고 보상 지급 에러: $e", tag: "STAMP_SERVICE");
      return null;
    }
  }

  Future<void> addFreeStamp(String userId, int amount) async {
    final userData = await getStampData(userId);
    if (userData == null) return;
    await _client
        .from('users')
        .update({
          'daily_stamps': (userData['daily_stamps'] ?? 0).toInt() + amount,
        })
        .eq('auth_uid', userId);
  }

  Future<Map<String, int>?> getAdRewardStatus(String userId) async {
    try {
      final userData = await getStampData(userId);
      if (userData == null) return null;
      final reward = await getRewardConfig('ad_watch_stamp');
      if (reward == null) return null;
      int usedCount = (userData['ad_reward_count'] ?? 0).toInt();
      if (userData['ad_reward_date']?.toString() !=
          DateFormat('yyyy-MM-dd').format(DateTime.now()))
        usedCount = 0;
      return {'used': usedCount, 'limit': (reward['daily_limit'] ?? 0).toInt()};
    } catch (e) {
      return null;
    }
  }
}
