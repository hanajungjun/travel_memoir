import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel_memoir/env.dart';

class PaymentService {
  static final _supabase = Supabase.instance.client;

  // 🎯 [방송국] UI 새로고침 전파를 위한 전역 신호기
  static final ValueNotifier<bool> refreshNotifier = ValueNotifier<bool>(false);

  // ✅ RevenueCat Entitlement ID 설정
  static const String _proEntitlementId = "PREMIUM ACCESS";
  static const String _vipEntitlementId = "VIP_ACCESS";

  // =========================
  // 🟢 플랫폼별 초기화 (init)
  // =========================
  static Future<void> init(String userId) async {
    try {
      // 🔑 플랫폼(iOS/Android)에 맞는 API 키 선택
      String apiKey = Platform.isIOS
          ? AppEnv.revenueCatAppleKey
          : AppEnv.revenueCatGoogleKey;

      // ⚠️ 특정 StoreKit 버전을 강제하지 않고 최신 설정을 따르도록 구성
      final configuration = PurchasesConfiguration(apiKey)..appUserID = userId;

      await Purchases.configure(configuration);
      debugPrint("✅ RevenueCat 초기화 완료 (Platform: ${Platform.operatingSystem})");
    } catch (e) {
      debugPrint("❌ RevenueCat 초기화 실패: $e");
    }
  }

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
      debugPrint("❌ 전체 오퍼링 가져오기 실패: $e");
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
      debugPrint("❌ 현재 오퍼링 가져오기 실패: $e");
      return null;
    }
  }

  // =========================
  // 3️⃣ 결제 진행 (에러 핸들링 강화)
  // =========================
  static Future<bool> purchasePackage(Package package) async {
    try {
      CustomerInfo customerInfo = await Purchases.purchasePackage(package);

      return await _handleCustomerInfo(
        customerInfo,
        package.storeProduct.identifier,
      );
    } on PlatformException catch (e) {
      // ⚠️ 영수증 누락 오류(Missing in receipt) 발생 시 강제로 복원 시도
      if (e.message?.contains("missing in the receipt") ?? false) {
        debugPrint("🔄 영수증 누락 감지: 구매 내역 강제 동기화(Restore) 시도 중...");
        try {
          CustomerInfo syncedInfo = await Purchases.restorePurchases();
          return await _handleCustomerInfo(
            syncedInfo,
            package.storeProduct.identifier,
          );
        } catch (restoreError) {
          debugPrint("❌ 자동 복원 실패: $restoreError");
        }
      }

      if (PurchasesErrorHelper.getErrorCode(e) !=
          PurchasesErrorCode.purchaseCancelledError) {
        debugPrint("❌ 결제 오류: ${e.message}");
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
      debugPrint("❌ 복원 실패: $e");
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
    // Pro 권한 확인
    final proEntitlement = info.entitlements.all[_proEntitlementId];
    final bool isProActive = proEntitlement?.isActive ?? false;

    // 💎 VIP 권한 확인
    final vipEntitlement = info.entitlements.all[_vipEntitlementId];
    final bool isVipActive = vipEntitlement?.isActive ?? false;

    // 🚀 [추가할 로그 위치] DB 업데이트 직전에 변수 값 확인
    debugPrint("------------------------------------------");
    debugPrint("🚩 [DB 반영 전 체크]");
    debugPrint("🚩 Entitlement ID (VIP): $_vipEntitlementId");
    debugPrint("🚩 RevenueCat 실시간 VIP 상태: $isVipActive"); // 👈 이게 핵심!
    debugPrint(
      "🚩 RevenueCat 전체 활성 권한: ${info.entitlements.active.keys.toList()}",
    );
    debugPrint("------------------------------------------");
    debugPrint("------------------------------------------");
    debugPrint("🔍 [결제체크] Pro 활성화 상태: $isProActive");
    debugPrint("🔍 [결제체크] VIP 활성화 상태: $isVipActive");
    debugPrint("🚨 [전체 권한 목록]: ${info.entitlements.active.keys.toList()}");

    // Supabase DB와 동기화 (먼저 수행)
    await _syncStatusToSupabase(
      isProActive: isProActive,
      proExpirationDate: proEntitlement?.expirationDate,
      isVipActive: isVipActive,
      vipExpirationDate: vipEntitlement?.expirationDate,
      vipLatestPurchaseDate: vipEntitlement?.latestPurchaseDate,
      rcId: info.originalAppUserId,
      productIdentifier: productIdentifier,
    );

    // ✨ [핵심] DB 동기화가 완전히 끝난 시점에 전파를 쏩니다!
    refreshNotifier.value = !refreshNotifier.value;

    return true;
  }

  // 🔄 외부 호출용 동기화 함수
  static Future<void> syncSubscriptionStatus() async {
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      await _handleCustomerInfo(customerInfo, null);
      debugPrint("🔄 최신 구독 및 VIP 정보 DB 동기화 완료");
    } catch (e) {
      debugPrint("❌ 동기화 실패: $e");
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
        'vip_since': vipLatestPurchaseDate,
      };

      await _supabase.from('users').update(updateData).eq('auth_uid', user.id);

      // (1-1). 🎯 진짜 "VIP 구독 상품"을 결제했을 때만 즉시 보너스 지급
      // 단순히 isVipActive인 것만 체크하면 코인 살 때마다 보너스가 터집니다.
      if (isVipActive && productIdentifier != null) {
        final id = productIdentifier.toLowerCase();

        // ✅ 상품 ID에 'vip'이 포함된 [구독권] 구매일 때만 보너스 실행
        if (id.contains('vip')) {
          await _supabase.rpc('grant_vip_bonus');
          debugPrint("🎁 VIP 정기 구독권 구매 보너스 지급 완료 (vip_stamps)");
        }
      }

      // (2) ✅ 멤버십 보너스 지급 (RPC)
      if (isVipActive) {
        await _supabase.rpc('grant_membership_coins');
      } else if (isProActive) {
        await _supabase.rpc('grant_membership_coins');
      }

      // (3) ✅ 코인 상품 구매 처리 (단발성 아이템)
      // if (productIdentifier != null &&
      //     productIdentifier.toLowerCase().contains('coins_')) {
      //   final addedCoins = _parseCoinAmount(productIdentifier);
      //   if (addedCoins > 0) {
      //     await _supabase.rpc(
      //       'increment_coins',
      //       params: {'amount': addedCoins},
      //     );
      //     debugPrint("💰 코인 $addedCoins개 충전 성공");
      //   }
      // }
      // (3) ✅ 코인(티켓) 상품 구매 처리
      if (productIdentifier != null &&
          productIdentifier.toLowerCase().contains('coins_')) {
        final addedCoins = _parseCoinAmount(productIdentifier);
        if (addedCoins > 0) {
          // 🎯 VIP 유저라도 코인을 샀으면 'paid_stamps'로 들어감
          await _supabase.rpc(
            'increment_coins', // 이 RPC가 users 테이블의 paid_stamps를 올리는지 확인!
            params: {'amount': addedCoins},
          );
          debugPrint("💰 유료 코인(티켓) $addedCoins개 충전 성공 (paid_stamps)");
        }
      }

      // (4) ✅ 지도 상품 구매 처리 (미국/일본/이탈리아)
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

      debugPrint("✅ [VIP/Pro/Map] Supabase 데이터 동기화 완료");
    } catch (e) {
      debugPrint("❌ DB 업데이트 오류: $e");
    }
  }
}
