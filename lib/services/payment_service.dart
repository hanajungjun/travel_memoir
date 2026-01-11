import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 추가

class PaymentService {
  static final _supabase = Supabase.instance.client;

  // 1. 판매 중인 패키지 가져오기
  static Future<Offerings?> getOfferings() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        return offerings;
      }
    } catch (e) {
      print("상품 가져오기 실패: $e");
    }
    return null;
  }

  // 2. 실제 결제 진행하기
  static Future<bool> purchasePackage(Package package) async {
    try {
      // ✅ 결제 요청
      CustomerInfo customerInfo = await Purchases.purchasePackage(package);

      // ✅ 'premium' 권한이 활성화되었는지 확인
      final premiumEntitlement =
          customerInfo.entitlements.all["TravelMemoir Pro"];

      if (premiumEntitlement?.isActive ?? false) {
        // 💰 결제 성공 시 DB 동기화 실행
        await _syncStatusToSupabase(
          expirationDate: premiumEntitlement?.expirationDate,
          rcId: customerInfo.originalAppUserId, // RevenueCat 고유 ID
        );
        return true;
      }
    } catch (e) {
      print("결제 취소 또는 실패: $e");
    }
    return false;
  }

  // 3. 🔐 (내부용) Supabase DB 업데이트
  static Future<void> _syncStatusToSupabase({
    String? expirationDate,
    required String rcId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('users')
          .update({
            'is_premium': true,
            'premium_until': expirationDate, // 만료일 저장
            'subscription_status': 'active',
            'revenuecat_id': rcId,
          })
          .eq('auth_uid', user.id); // 유저님의 테이블 구조인 auth_uid와 매칭

      print("✅ Supabase 프리미엄 상태 업데이트 완료!");
    } catch (e) {
      print("❌ DB 업데이트 중 오류 발생: $e");
    }
  }
}
