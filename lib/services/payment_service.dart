import 'package:flutter/services.dart'; // ✅ 이 줄을 추가하세요!
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentService {
  static final _supabase = Supabase.instance.client;
  // ✅ RevenueCat에서 설정한 Entitlement ID와 정확히 일치해야 합니다.
  static const String _entitlementId = "TravelMemoir Pro";

  // 1. 판매 중인 패키지 가져오기
  static Future<Offerings?> getOfferings() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        return offerings;
      }
    } catch (e) {
      print("❌ 상품 가져오기 실패: $e");
    }
    return null;
  }

  // 2. 실제 결제 진행하기
  static Future<bool> purchasePackage(Package package) async {
    try {
      CustomerInfo customerInfo = await Purchases.purchasePackage(package);
      return await _handleCustomerInfo(customerInfo);
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        print("❌ 결제 오류: ${e.message}");
      }
      return false;
    }
  }

  // 3. ✅ [추가] 구독 복원하기 (애플 심사 필수 항목)
  static Future<bool> restorePurchases() async {
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      return await _handleCustomerInfo(customerInfo);
    } catch (e) {
      print("❌ 복원 실패: $e");
      return false;
    }
  }

  // 4. ✅ [추가] 앱 실행 시 또는 프로필 로드 시 구독 상태 최신화
  static Future<void> updateCustomerStatus() async {
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      await _handleCustomerInfo(customerInfo);
    } catch (e) {
      print("❌ 상태 업데이트 실패: $e");
    }
  }

  // 5. 🔐 [내부용] 결제/복원 후 정보 처리 및 DB 동기화
  static Future<bool> _handleCustomerInfo(CustomerInfo info) async {
    final entitlement = info.entitlements.all[_entitlementId];
    final bool isActive = entitlement?.isActive ?? false;

    // 프리미엄 상태를 Supabase와 동기화
    await _syncStatusToSupabase(
      isActive: isActive,
      expirationDate: entitlement?.expirationDate,
      rcId: info.originalAppUserId,
    );

    return isActive;
  }

  // 6. 🔐 Supabase DB 업데이트
  static Future<void> _syncStatusToSupabase({
    required bool isActive,
    String? expirationDate,
    required String rcId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('users')
          .update({
            'is_premium': isActive,
            'premium_until': expirationDate, // null이면 만료 혹은 무료 유저
            'subscription_status': isActive ? 'active' : 'none',
            'revenuecat_id': rcId,
          })
          .eq('auth_uid', user.id);

      print("✅ Supabase 구독 상태(${isActive ? '유료' : '무료'}) 업데이트 완료!");
    } catch (e) {
      print("❌ DB 업데이트 중 오류 발생: $e");
    }
  }
}
