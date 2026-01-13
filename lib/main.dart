import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'firebase_options.dart';
import 'services/prompt_cache.dart';
import 'env.dart';
import 'app/app.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  EasyLocalization.logger.enableLevels = [];

  // ✅ 0. 설정값 로드 (온보딩 및 알림 설정)
  final prefs = await SharedPreferences.getInstance();
  final bool onboardingDone = prefs.getBool('onboarding_done') ?? false;
  final bool notificationEnabled =
      prefs.getBool('notification_enabled') ?? true;

  // ✅ 1. AdMob 초기화
  await MobileAds.instance.initialize();

  // ✅ 2. Firebase 초기화
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ⭐ [수정] FCM 토큰 출력 - iOS 시뮬레이터 에러 방지 로직
  String? token;
  try {
    if (Platform.isIOS) {
      // iOS일 경우 APNS 토큰이 먼저 확보되었는지 확인 (시뮬레이터는 여기서 null 반환)
      String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken != null) {
        token = await FirebaseMessaging.instance.getToken();
      } else {
        debugPrint("🎯 알림: iOS 시뮬레이터 또는 APNS 설정 미비로 FCM 토큰 호출을 건너뜁니다.");
      }
    } else {
      // 안드로이드는 바로 가져옴
      token = await FirebaseMessaging.instance.getToken();
    }
  } catch (e) {
    debugPrint("🎯 FCM 토큰 가져오기 중 오류 발생: $e");
  }

  if (token != null) {
    print("🎯 내 FCM 토큰: $token");
  }

  // ✅ 3. 백그라운드 메시지 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ✅ 4. 🔔 알림 설정 (권한 요청 및 토글 상태 반영)
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // 알림 권한 요청
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  // [보강] iOS APNS 토큰 확보 시도 (에러 방지를 위해 try-catch 권장하나 원본 유지)
  if (Platform.isIOS) {
    await messaging.getAPNSToken();
  }

  // 설정 페이지의 토글 상태를 포그라운드 알림에 반영
  await messaging.setForegroundNotificationPresentationOptions(
    alert: notificationEnabled,
    badge: notificationEnabled,
    sound: notificationEnabled,
  );

  // 포그라운드 리스너
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (notificationEnabled) {
      print("🔔 포그라운드 메시지 수신: ${message.notification?.title}");
    } else {
      print("🔕 알림 차단 상태: 메시지를 받았지만 팝업을 띄우지 않습니다.");
    }
  });

  // ✅ 5. Supabase 초기화
  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    anonKey: AppEnv.supabaseAnonKey,
  );

  // ✅ 6. 프롬프트 캐시 로드
  await PromptCache.refresh();

  // ✅ 7. intl 로케일 초기화
  await initializeDateFormatting('ko_KR', null);

  // ✅ 8. 카카오 SDK 초기화
  KakaoSdk.init(
    nativeAppKey: AppEnv.kakaoNativeAppKey,
    javaScriptAppKey: AppEnv.kakaoJavaScriptKey,
  );

  // ✅ 9. 💰 RevenueCat 초기화
  await _initRevenueCat();

  // ✅ 10. TravelMemoirApp 실행
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ko'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ko'),
      useOnlyLangCode: true,
      child: TravelMemoirApp(showOnboarding: !onboardingDone),
    ),
  );
}

Future<void> _initRevenueCat() async {
  await Purchases.setLogLevel(LogLevel.debug);
  PurchasesConfiguration configuration;

  if (Platform.isAndroid) {
    configuration = PurchasesConfiguration(AppEnv.revenueCatGoogleKey);
  } else if (Platform.isIOS) {
    configuration = PurchasesConfiguration(AppEnv.revenueCatAppleKey);
  } else {
    return;
  }
  await Purchases.configure(configuration);
}
