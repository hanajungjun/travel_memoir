import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/prompt_cache.dart';
import 'env.dart';
import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 1. Supabase 먼저 초기화 (필수)
  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    anonKey: AppEnv.supabaseAnonKey,
  );

  // ✅ 2. 프롬프트 캐시 로드 (이제 안전)
  await PromptCache.refresh();

  // ✅ 3. intl 로케일 초기화
  await initializeDateFormatting('ko_KR', null);

  // ✅ 4. 카카오 SDK 초기화
  KakaoSdk.init(
    nativeAppKey: AppEnv.kakaoNativeAppKey,
    javaScriptAppKey: AppEnv.kakaoJavaScriptKey,
  );

  runApp(const TravelMemoirApp());
}
