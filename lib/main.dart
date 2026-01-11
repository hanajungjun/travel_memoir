import 'dart:io'; // ✅ Platform 확인을 위해 추가
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:purchases_flutter/purchases_flutter.dart'; // 이미 있음!

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

  // ✅ 0. 온보딩 완료 여부 확인
  final prefs = await SharedPreferences.getInstance();
  final bool onboardingDone = prefs.getBool('onboarding_done') ?? false;

  // ✅ 1. AdMob 초기화
  await MobileAds.instance.initialize();

  // ✅ 2. Firebase 초기화
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ 3. 백그라운드 메시지 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ✅ 4. 🔔 알림 권한 요청
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

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

  // ✅ 9. 💰 RevenueCat 초기화 추가
  await _initRevenueCat();

  // ✅ 10. TravelMemoirApp 실행
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ko'), Locale('en')],
      path: 'assets/translations/',
      fallbackLocale: const Locale('ko'),
      useOnlyLangCode: true,
      child: TravelMemoirApp(showOnboarding: !onboardingDone),
    ),
  );
}

// ✅ RevenueCat 초기화 함수 별도 분리 (가독성)
Future<void> _initRevenueCat() async {
  // 개발 중에는 로그를 상세히 봐서 결제 흐름을 파악하는 게 좋아요!
  await Purchases.setLogLevel(LogLevel.debug);

  PurchasesConfiguration configuration;

  if (Platform.isAndroid) {
    // AppEnv에 구글 API 키가 등록되어 있다고 가정합니다.
    configuration = PurchasesConfiguration(AppEnv.revenueCatGoogleKey);
  } else if (Platform.isIOS) {
    // AppEnv에 애플 API 키가 등록되어 있다고 가정합니다.
    configuration = PurchasesConfiguration(AppEnv.revenueCatAppleKey);
  } else {
    return; // 다른 플랫폼은 결제 지원 안 함
  }

  await Purchases.configure(configuration);
}
