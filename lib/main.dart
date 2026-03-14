import 'dart:io';
import 'dart:math';
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
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:travel_memoir/app/route_observer.dart';
import 'services/network_service.dart';
import 'firebase_options.dart';
import 'services/prompt_cache.dart';
import 'env.dart';
import 'app/app.dart';
import 'package:travel_memoir/services/country_service.dart';
import 'package:travel_memoir/features/guide/tutorial_manager.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> _initMediaStorePermission() async {
  if (Platform.isAndroid) {
    // 안드로이드 13 (SDK 33) 이상인지 확인하기 위해 device_info_plus를 쓰는 게 좋지만,
    // 일단은 가장 안전하게 모든 미디어 권한을 요청하는 방식입니다.

    // 1. 권한 목록 준비
    List<Permission> permissions = [];

    // 실제로는 기기 버전을 체크해서 넣는 게 베스트입니다.
    // 여기서는 일단 모든 케이스를 대응하도록 구성합니다.
    permissions.add(Permission.photos); // Android 13+ 이미지
    permissions.add(Permission.videos); // Android 13+ 영상
    permissions.add(Permission.storage); // Android 12 이하 공용 저장소

    // 2. 한꺼번에 요청
    Map<Permission, PermissionStatus> statuses = await permissions.request();

    // 3. 결과 확인 (하나라도 승인되면 일단 진행)
    bool isGranted =
        statuses[Permission.photos]?.isGranted == true ||
        statuses[Permission.storage]?.isGranted == true;

    if (isGranted) {
      debugPrint('📸 갤러리 접근 권한 확보 성공');
    } else {
      debugPrint('❌ 권한 거절됨');
    }
  }
}

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await EasyLocalization.ensureInitialized();
  EasyLocalization.logger.enableLevels = [];

  final prefs = await SharedPreferences.getInstance();
  final bool onboardingDone = prefs.getBool('onboarding_done') ?? false;
  final bool notificationEnabled =
      prefs.getBool('notification_enabled') ?? true;

  await MobileAds.instance.initialize();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  CountryService.prefetch(); // ✅ await 없이 백그라운드로 미리 로드

  String? token;
  try {
    if (Platform.isIOS) {
      String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken != null)
        token = await FirebaseMessaging.instance.getToken();
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

  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    anonKey: AppEnv.supabaseAnonKey,
  );

  // 🎯 [수정] app_config 테이블의 loading_image_url 컬럼 읽기
  // 🎯 [핵심] app_config 테이블에서 loading_image_url(상대 경로) 불러오기
  String? adminLoadingImageUrl;
  try {
    final res = await Supabase.instance.client
        .from('app_config')
        .select('loading_images') // 🎯 컬럼명을 배열 컬럼으로 변경
        .eq('id', 1)
        .maybeSingle();

    if (res != null && res['loading_images'] != null) {
      // 1. DB에서 이미지 경로 리스트(배열)를 가져옴
      final List<dynamic> pathList = res['loading_images'];

      if (pathList.isNotEmpty) {
        // 2. Random 객체 생성 후 리스트 중 하나를 무작위 선택
        final random = Random();
        final String selectedPath = pathList[random.nextInt(pathList.length)];

        // 3. 선택된 상대 경로를 Public URL로 변환
        adminLoadingImageUrl = Supabase.instance.client.storage
            .from('travel_images')
            .getPublicUrl(selectedPath);

        debugPrint("🎲 랜덤 로딩 이미지 선정: $selectedPath");
      }
    }
  } catch (e) {
    debugPrint("⚠️ 설정 로드 실패: $e");
  }

  await PromptCache.refresh();
  await initializeDateFormatting('ko_KR', null);

  KakaoSdk.init(
    nativeAppKey: AppEnv.kakaoNativeAppKey,
    javaScriptAppKey: AppEnv.kakaoJavaScriptKey,
  );

  await _initRevenueCat();
  await NetworkService().initialize();
  await TutorialManager.init();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ko'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ko'),
      useOnlyLangCode: true,
      child: _TravelMemoirAppWrapper(
        showOnboarding: !onboardingDone,
        adminLoadingImageUrl: adminLoadingImageUrl,
      ),
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

class _TravelMemoirAppWrapper extends StatefulWidget {
  final bool showOnboarding;
  final String? adminLoadingImageUrl;

  const _TravelMemoirAppWrapper({
    required this.showOnboarding,
    this.adminLoadingImageUrl,
  });

  @override
  State<_TravelMemoirAppWrapper> createState() =>
      _TravelMemoirAppWrapperState();
}

class _TravelMemoirAppWrapperState extends State<_TravelMemoirAppWrapper> {
  bool _isLoadingComplete = false;

  @override
  void initState() {
    super.initState();
    _loadMyToken();
    _initNotificationPermission(); // 🔔 안드로이드 13+ 알림 권한 시스템 팝업 요청
    _initMediaStorePermission(); // ✅ [추가] 갤러리 접근 권한 요청

    Future.delayed(const Duration(seconds: 2), () async {
      if (mounted) {
        setState(() => _isLoadingComplete = true);
      }
    });
  }

  Future<void> _loadMyToken() async {
    String? token = await FirebaseMessaging.instance.getToken();
    print("--------- 내 기기 FCM 토큰 ---------");
    print(token);
    print("----------------------------------");
  }

  // 🎯 배포 버전에서 알림 팝업을 확실히 띄우기 위한 함수
  Future<void> _initNotificationPermission() async {
    if (Platform.isAndroid) {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // 안드로이드 시스템에 알림 권한을 정식으로 요청합니다.
      // 이 시점에 안드로이드 13 이상 기기에서 "알림 허용" 팝업이 뜹니다.
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('🔔 사용자가 알림 권한을 승인함');
      } else {
        debugPrint('🔕 사용자가 알림 권한을 거절함');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoadingComplete) {
      return _DynamicLoadingScreen(imageUrl: widget.adminLoadingImageUrl);
    }

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
        showOnboarding: widget.showOnboarding,
      ),
    );
  }
}

class _DynamicLoadingScreen extends StatefulWidget {
  final String? imageUrl;
  const _DynamicLoadingScreen({this.imageUrl});

  @override
  State<_DynamicLoadingScreen> createState() => _DynamicLoadingScreenState();
}

class _DynamicLoadingScreenState extends State<_DynamicLoadingScreen> {
  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            if (widget.imageUrl != null)
              Image.network(
                widget.imageUrl!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Center(child: CircularProgressIndicator()),
              )
            else
              const Center(child: CircularProgressIndicator()),
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 50),
                child: CircularProgressIndicator(color: Colors.blueAccent),
              ),
            ),
          ],
        ),
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
