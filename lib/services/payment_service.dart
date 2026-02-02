import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentService {
  static final _supabase = Supabase.instance.client;

  // ✅ RevenueCat Entitlement IDs (대시보드와 반드시 일치시켜주세요)
  static const String _proEntitlementId = "TravelMemoir Pro";
  static const String _vipEntitlementId = "TravelMemoir VIP"; // 💎 VIP 전용 ID 추가

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
      // 복원 시에는 productIdentifier를 알 수 없으므로 null 전달
      return await _handleCustomerInfo(customerInfo, null);
    } catch (e) {
      print("❌ 복원 실패: $e");
      return false;
    }
  }

  // =========================
  // 5️⃣ CustomerInfo 처리 게이트 (VIP 로직 추가)
  // =========================
  static Future<bool> _handleCustomerInfo(
    CustomerInfo info,
    String? productIdentifier,
  ) async {
    // Pro 권한 확인
    final proEntitlement = info.entitlements.all[_proEntitlementId];
    final bool isProActive = proEntitlement?.isActive ?? false;

    // 💎 VIP 권한 확인
    final vipEntitlement = info.entitlements.all[_vipEntitlementId];
    final bool isVipActive = vipEntitlement?.isActive ?? false;

    await _syncStatusToSupabase(
      isProActive: isProActive,
      proExpirationDate: proEntitlement?.expirationDate,
      isVipActive: isVipActive,
      vipExpirationDate: vipEntitlement?.expirationDate,
      vipLatestPurchaseDate: vipEntitlement?.latestPurchaseDate,
      rcId: info.originalAppUserId,
      productIdentifier: productIdentifier,
    );

    return true;
  }

  // 🔄 외부 호출용 동기화 함수
  static Future<void> syncSubscriptionStatus() async {
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      await _handleCustomerInfo(customerInfo, null);
      print("🔄 최신 구독 및 VIP 정보 DB 동기화 완료");
    } catch (e) {
      print("❌ 동기화 실패: $e");
    }
  }

  // =========================
  // 6️⃣ Supabase 동기화 (구독 + VIP + 코인 + 지도)
  // =========================
  static Future<void> _syncStatusToSupabase({
    required bool isProActive,
    String? proExpirationDate,
    required bool isVipActive,
    String? vipExpirationDate,
    String? vipLatestPurchaseDate,
    required String rcId,
    String? productIdentifier,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // (1) 통합 유저 상태 데이터 구성
      final updateData = {
        'is_premium': isProActive,
        'premium_until': proExpirationDate,
        'subscription_status': (isVipActive || isProActive) ? 'active' : 'none',
        'revenuecat_id': rcId,
        // 💎 VIP 정보 업데이트
        'is_vip': isVipActive,
        'vip_until': vipExpirationDate,
        'vip_since': vipLatestPurchaseDate, // 최근 구매일을 가입일로 활용
      };

      await _supabase.from('users').update(updateData).eq('auth_uid', user.id);

      // (2) ✅ 멤버십 보너스 지급 (RPC)
      if (isVipActive) {
        // VIP 유저는 별도의 VIP 코인/스탬프 지급 로직이 있다면 여기서 실행
        //  await _supabase.rpc('grant_vip_membership_bonus');
        await _supabase.rpc('grant_membership_coins');
      } else if (isProActive) {
        // 일반 프리미엄 유저 코인 지급
        await _supabase.rpc('grant_membership_coins');
      }

      // (3) ✅ 코인 상품 구매 처리 (단발성 아이템)
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
        if (productIdentifier.contains('usa'))
          mapId = 'us';
        else if (productIdentifier.contains('japan'))
          mapId = 'jp';
        else if (productIdentifier.contains('italy'))
          mapId = 'it';

        if (mapId.isNotEmpty) {
          await _supabase.rpc('add_map_to_user', params: {'map_id': mapId});
        }
      }

      print("✅ [VIP/Pro] Supabase 데이터 동기화 완료");
    } catch (e) {
      print("❌ DB 업데이트 오류: $e");
    }
  }
}
