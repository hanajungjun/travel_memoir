import 'dart:io';
import 'dart:ui' as ui; // ✅ ui.TextDirection 해결을 위해 추가
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

  // 2. 저장된 설정값 로드 (온보딩 완료 여부 확인)
  final prefs = await SharedPreferences.getInstance();
  final bool onboardingDone = prefs.getBool('onboarding_done') ?? false;
  final bool notificationEnabled =
      prefs.getBool('notification_enabled') ?? true;

  // 3. 광고(AdMob) 초기화
  await MobileAds.instance.initialize();

  // 4. Firebase 초기화 및 알림 설정
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // FCM 토큰 처리 (iOS 시뮬레이터 대응 포함)
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
      // 래퍼 위젯을 통해 인터넷 체크와 온보딩 여부를 관리합니다.
      child: _TravelMemoirAppWrapper(showOnboarding: !onboardingDone),
    ),
  );
}

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

// ---------------------------------------------------------------------
// 위젯 클래스들
// ---------------------------------------------------------------------

/// 앱 전체를 감싸서 인터넷 상태를 감시하고 온보딩을 제어하는 래퍼
class _TravelMemoirAppWrapper extends StatelessWidget {
  final bool showOnboarding;

  const _TravelMemoirAppWrapper({required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: NetworkService().isConnectedNotifier,
      builder: (context, isConnected, child) {
        return Stack(
          textDirection: ui.TextDirection.ltr, // ✅ 에러 방지: ui. 추가
          children: [
            // 1층: 메인 앱 화면
            // (key를 추가하여 PlatformView 충돌 에러 방지)
            child!,

            // 2층: 오프라인 시 안내 화면 덮기
            if (!isConnected) const _OfflineFullScreen(),
          ],
        );
      },
      // ✅ 실제 앱 위젯 호출 (기존 로직 유지)
      child: TravelMemoirApp(
        key: const ValueKey('MainApp'), // ✅ 뷰 재사용 에러 방지용 키
        showOnboarding: showOnboarding,
      ),
    );
  }
}

/// 인터넷 끊겼을 때 나타나는 오프라인 화면
class _OfflineFullScreen extends StatelessWidget {
  const _OfflineFullScreen();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withAlpha(204), // 반투명 검정 (0.8 opacity)
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.wifi_off_rounded, size: 100, color: Colors.white),
            SizedBox(height: 20),
            DefaultTextStyle(
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
              child: Text('인터넷 연결이 필요합니다.'),
            ),
            SizedBox(height: 10),
            DefaultTextStyle(
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                decoration: TextDecoration.none,
              ),
              child: Text(
                'Wi-Fi 또는 셀룰러 데이터를 확인해주세요.\n연결되면 자동으로 화면이 돌아옵니다.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
