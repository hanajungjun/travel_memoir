import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // ✅ 1. AdMob 패키지 추가

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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

  // ✅ 0. AdMob 초기화 (시동 걸기)
  await MobileAds.instance.initialize();

  // ✅ 1. Firebase 초기화 (옵션 포함, 필수)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ 2. 백그라운드 메시지 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ✅ 3. 🔔 알림 권한 요청
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // ✅ 4. Supabase 초기화
  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    anonKey: AppEnv.supabaseAnonKey,
  );

  // ✅ 5. 프롬프트 캐시 로드
  await PromptCache.refresh();

  // ✅ 6. intl 로케일 초기화
  await initializeDateFormatting('ko_KR', null);

  // ✅ 7. 카카오 SDK 초기화
  KakaoSdk.init(
    nativeAppKey: AppEnv.kakaoNativeAppKey,
    javaScriptAppKey: AppEnv.kakaoJavaScriptKey,
  );

  runApp(const TravelMemoirApp());
}
