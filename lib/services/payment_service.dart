import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentService {
  static final _supabase = Supabase.instance.client;

  // ✅ RevenueCat Entitlement ID (대시보드와 반드시 일치)
  static const String _entitlementId = "TravelMemoir Pro";

  // =========================
  // 0️⃣ coins_50 / coins_100 / coins_200 파싱
  // =========================
  static int _parseCoinAmount(String productIdentifier) {
    final match = RegExp(
      r'coins_(\d+)',
    ).firstMatch(productIdentifier.toLowerCase());
    return int.tryParse(match?.group(1) ?? '0') ?? 0;
  }

  // =========================
  // 1️⃣ 모든 오퍼링 정보 가져오기
  // =========================
  static Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      print("❌ 전체 오퍼링 가져오기 실패: $e");
      return null;
    }
  }

  // =========================
  // 2️⃣ 현재 활성화된 오퍼링 가져오기
  // =========================
  static Future<Offering?> getCurrentOffering() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      return offerings.current;
    } catch (e) {
      print("❌ 현재 오퍼링 가져오기 실패: $e");
      return null;
    }
  }

  // =========================
  // 3️⃣ 결제 진행
  // =========================
  static Future<bool> purchasePackage(Package package) async {
    try {
      CustomerInfo customerInfo = await Purchases.purchasePackage(package);

      return await _handleCustomerInfo(
        customerInfo,
        package.storeProduct.identifier,
      );
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) !=
          PurchasesErrorCode.purchaseCancelledError) {
        print("❌ 결제 오류: ${e.message}");
      }
      return false;
    }
  }

  // =========================
  // 4️⃣ 구매 복원
  // =========================
  static Future<bool> restorePurchases() async {
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();

      final entitlements = customerInfo.entitlements.all[_entitlementId];
      final bool isActive = entitlements?.isActive ?? false;

      await _syncStatusToSupabase(
        isActive: isActive,
        expirationDate: entitlements?.expirationDate,
        rcId: customerInfo.originalAppUserId,
      );

      return true;
    } catch (e) {
      print("❌ 복원 실패: $e");
      return false;
    }
  }

  // =========================
  // 5️⃣ CustomerInfo 처리 게이트
  // =========================
  static Future<bool> _handleCustomerInfo(
    CustomerInfo info,
    String? productIdentifier,
  ) async {
    final entitlement = info.entitlements.all[_entitlementId];
    final bool isActive = entitlement?.isActive ?? false;

    await _syncStatusToSupabase(
      isActive: isActive,
      expirationDate: entitlement?.expirationDate,
      rcId: info.originalAppUserId,
      productIdentifier: productIdentifier,
    );

    return true;
  }

  // 🌟 [추가] 외부에서 언제든 "지금 상태로 DB랑 맞춰!"라고 부를 수 있는 함수
  static Future<void> syncSubscriptionStatus() async {
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      await _handleCustomerInfo(customerInfo, null);
      print("🔄 최신 구독 정보 DB 동기화 완료");
    } catch (e) {
      print("❌ 동기화 실패: $e");
    }
  }

  // =========================
  // 6️⃣ Supabase 동기화 (구독 + 코인 + 지도)
  // =========================
  static Future<void> _syncStatusToSupabase({
    required bool isActive,
    String? expirationDate,
    required String rcId,
    String? productIdentifier,
  }) async {
    print("📅 레비뉴캣이 알려준 만료일: $expirationDate");
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // (1) 구독 기본 상태 업데이트
      final updateData = {
        'is_premium': isActive,
        'premium_until': expirationDate,
        'subscription_status': isActive ? 'active' : 'none',
        'revenuecat_id': rcId,
      };

      await _supabase.from('users').update(updateData).eq('auth_uid', user.id);

      // (2) ✅ 구독 보너스 코인 지급 (1회만!)
      if (isActive) {
        await _supabase.rpc('grant_membership_coins');
      }

      // (3) ✅ 코인 상품 구매 처리 (coins_50 / 100 / 200)
      if (productIdentifier != null &&
          productIdentifier.toLowerCase().contains('coins_')) {
        final addedCoins = _parseCoinAmount(productIdentifier);

        if (addedCoins > 0) {
          await _supabase.rpc(
            'increment_coins',
            params: {'amount': addedCoins},
          );
          print("💰 코인 $addedCoins개 충전 성공");
        }
      }

      // (4) 지도 상품 구매 처리
      if (productIdentifier != null &&
          productIdentifier.toLowerCase().contains('map')) {
        String mapId = '';
        if (productIdentifier.contains('usa')) {
          mapId = 'us';
        } else if (productIdentifier.contains('japan')) {
          mapId = 'jp';
        } else if (productIdentifier.contains('italy')) {
          mapId = 'it';
        }

        if (mapId.isNotEmpty) {
          await _supabase.rpc('add_map_to_user', params: {'map_id': mapId});
          print("🗺️ 지도 $mapId 추가 완료");
        }
      }

      print("✅ Supabase 데이터 동기화 완료");
    } catch (e) {
      print("❌ DB 업데이트 오류: $e");
    }
  }
}
