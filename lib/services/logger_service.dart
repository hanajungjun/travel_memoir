import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as dev;

class LoggerService {
  // 싱글톤 패턴 적용
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  final _supabase = Supabase.instance.client;

  /// ✅ 로그 기록 및 Supabase 전송
  Future<void> log(String message, {String? tag, String level = 'info'}) async {
    final user = _supabase.auth.currentUser;
    final timestamp = DateTime.now().toString().split(' ').last.substring(0, 8);

    // 1. 디버그 콘솔 출력 (개발용)
    if (kDebugMode) {
      dev.log(message, name: tag ?? 'APP');
    }

    try {
      // 2. Supabase app_logs 테이블에 인서트
      await _supabase.from('app_logs').insert({
        'user_id': user?.id,
        'tag': tag ?? 'GENERAL',
        'message': message,
        'level': level,
        'device_info': {
          'platform': defaultTargetPlatform.toString(),
          'is_release': kReleaseMode,
        },
      });
    } catch (e) {
      // 네트워크 오류 등으로 전송 실패 시 최소한의 콘솔 로그 남김
      debugPrint("❌ 로그 업로드 실패: $e");
    }
  }

  // 편리한 사용을 위한 헬퍼 메서드들
  Future<void> error(String message, {String? tag}) =>
      log(message, tag: tag, level: 'error');
  Future<void> info(String message, {String? tag}) =>
      log(message, tag: tag, level: 'info');
  Future<void> warn(String message, {String? tag}) =>
      log(message, tag: tag, level: 'warn');
}
