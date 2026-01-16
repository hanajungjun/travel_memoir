import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentService {
  static final _supabase = Supabase.instance.client;

  // ✅ RevenueCat Entitlement ID (대시보드와 일치해야 함)
  static const String _entitlementId = "TravelMemoir Pro";

  // 1. 모든 판매 상품 정보 가져오기 (복수형 - PayManagementPage용)
  static Future<Offerings?> getOfferings() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      return offerings;
    } catch (e) {
      print("❌ 전체 상품 가져오기 실패: $e");
      return null;
    }
  }

  // 2. 현재 활성화된 오퍼링만 가져오기 (단수형 - CoinPaywall용)
  static Future<Offering?> getCurrentOffering() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      return offerings.current;
    } catch (e) {
      print("❌ 현재 오퍼링 가져오기 실패: $e");
      return null;
    }
  }

  // 3. 실제 결제 진행하기
  static Future<bool> purchasePackage(Package package) async {
    try {
      CustomerInfo customerInfo = await Purchases.purchasePackage(package);
      // 어떤 상품을 샀는지 ID를 함께 넘깁니다.
      return await _handleCustomerInfo(
        customerInfo,
        package.storeProduct.identifier,
      );
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        print("❌ 결제 오류: ${e.message}");
      }
      return false;
    }
  }

  // 4. 구독 복원하기
  static Future<bool> restorePurchases() async {
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      return await _handleCustomerInfo(customerInfo, null);
    } catch (e) {
      print("❌ 복원 실패: $e");
      return false;
    }
  }

  // 5. 🔐 [내부용] 정보 처리 및 DB 동기화
  static Future<bool> _handleCustomerInfo(
    CustomerInfo info,
    String? productIdentifier,
  ) async {
    final entitlement = info.entitlements.all[_entitlementId];
    final bool isActive = entitlement?.isActive ?? false;

    // Supabase DB 업데이트
    await _syncStatusToSupabase(
      isActive: isActive,
      expirationDate: entitlement?.expirationDate,
      rcId: info.originalAppUserId,
      productIdentifier: productIdentifier,
    );

    // 유료 권한이 있거나, 방금 코인 상품을 샀다면 true 반환
    return isActive ||
        (productIdentifier != null && productIdentifier.contains('coin'));
  }

  // 6. 🔐 Supabase DB 업데이트
  static Future<void> _syncStatusToSupabase({
    required bool isActive,
    String? expirationDate,
    required String rcId,
    String? productIdentifier,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // (1) 구독 상태 업데이트 데이터
      Map<String, dynamic> updateData = {
        'is_premium': isActive,
        'premium_until': expirationDate,
        'subscription_status': isActive ? 'active' : 'none',
        'revenuecat_id': rcId,
      };

      // (2) 코인 상품 구매 시 코인 개수 증가 (RPC 호출)
      if (productIdentifier != null && productIdentifier.contains('coin')) {
        int addedCoins =
            int.tryParse(productIdentifier.replaceAll(RegExp(r'[^0-9]'), '')) ??
            0;
        if (addedCoins > 0) {
          await _supabase.rpc(
            'increment_coins',
            params: {'amount': addedCoins},
          );
          print("💰 코인 $addedCoins개 충전 완료!");
        }
      }

      await _supabase.from('users').update(updateData).eq('auth_uid', user.id);
      print("✅ Supabase 동기화 성공!");
    } catch (e) {
      print("❌ DB 업데이트 오류: $e");
    }
  }
}
