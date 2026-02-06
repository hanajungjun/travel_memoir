import 'dart:io';
import 'dart:ui' as ui;
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
import 'package:travel_memoir/app/route_observer.dart'; // 👈 기존에 있던 옵저버 파일 임포트

// 우리가 만든 서비스들
import 'services/network_service.dart';
import 'firebase_options.dart';
import 'services/prompt_cache.dart';
import 'env.dart';
import 'app/app.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  // 1. Flutter 엔진 및 기본 설정 초기화
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  EasyLocalization.logger.enableLevels = [];

  // 2. 저장된 설정값 로드
  final prefs = await SharedPreferences.getInstance();
  final bool onboardingDone = prefs.getBool('onboarding_done') ?? false;
  final bool notificationEnabled =
      prefs.getBool('notification_enabled') ?? true;

  // 3. 광고(AdMob) 초기화
  await MobileAds.instance.initialize();

  // 4. Firebase 초기화 및 알림 설정
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  String? token;
  try {
    if (Platform.isIOS) {
      String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken != null) {
        token = await FirebaseMessaging.instance.getToken();
      }
    } else {
      token = await FirebaseMessaging.instance.getToken();
    }
  } catch (e) {
    debugPrint("🎯 FCM 토큰 오류: $e");
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);
  await messaging.setForegroundNotificationPresentationOptions(
    alert: notificationEnabled,
    badge: notificationEnabled,
    sound: notificationEnabled,
  );

  // 5. 백엔드 및 기타 서비스 초기화
  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    anonKey: AppEnv.supabaseAnonKey,
  );

  // 🚀 [추가 로직] 스탬프 자동 리셋 안전장치???
  //await _checkAndResetStamps();

  await PromptCache.refresh();
  await initializeDateFormatting('ko_KR', null);

  // 6. 카카오 SDK 초기화
  KakaoSdk.init(
    nativeAppKey: AppEnv.kakaoNativeAppKey,
    javaScriptAppKey: AppEnv.kakaoJavaScriptKey,
  );

  // 7. 💰 RevenueCat 결제 초기화
  await _initRevenueCat();

  // 8. 🌐 네트워크 감시자 시작
  await NetworkService().initialize();

  // 9. 앱 실행
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ko'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ko'),
      useOnlyLangCode: true,
      child: _TravelMemoirAppWrapper(showOnboarding: !onboardingDone),
    ),
  );
}

// 🛡️ 스탬프 리셋 안전장치 함수
// Future<void> _checkAndResetStamps() async {
//   try {
//     final client = Supabase.instance.client;
//     // 세션(로그인 상태)이 있을 때만 RPC 호출
//     if (client.auth.currentSession != null) {
//       await client.rpc('reset_daily_stamps');
//       debugPrint("✅ [VIP/일반] 일일 스탬프 리셋 체크 완료");
//     }
//   } catch (e) {
//     // 네트워크 오류 등으로 실패해도 앱 실행은 방해하지 않도록 예외 처리
//     debugPrint("⚠️ 스탬프 리셋 호출 실패 (미로그인 또는 네트워크): $e");
//   }
// }

// RevenueCat 초기화 상세
Future<void> _initRevenueCat() async {
  await Purchases.setLogLevel(LogLevel.debug);
  PurchasesConfiguration configuration;
  if (Platform.isAndroid) {
    configuration = PurchasesConfiguration(AppEnv.revenueCatGoogleKey);
  } else if (Platform.isIOS) {
    configuration = PurchasesConfiguration("appl_GOvqLsLAoeTPEMVnmhUHjGJFGCY");
  } else {
    return;
  }
  await Purchases.configure(configuration);
}

class _TravelMemoirAppWrapper extends StatelessWidget {
  final bool showOnboarding;

  const _TravelMemoirAppWrapper({required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: NetworkService().isConnectedNotifier,
      builder: (context, isConnected, child) {
        return Stack(
          textDirection: ui.TextDirection.ltr,
          children: [child!, if (!isConnected) const _OfflineFullScreen()],
        );
      },
      child: TravelMemoirApp(
        key: const ValueKey('MainApp'),
        showOnboarding: showOnboarding,
      ),
    );
  }
}

class _OfflineFullScreen extends StatelessWidget {
  const _OfflineFullScreen();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Material(
        color: Colors.black.withAlpha(204),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.wifi_off_rounded, size: 100, color: Colors.white),
              SizedBox(height: 20),
              Text(
                '인터넷 연결이 필요합니다.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Wi-Fi 또는 셀룰러 데이터를 확인해주세요.\n연결되면 자동으로 화면이 돌아옵니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
