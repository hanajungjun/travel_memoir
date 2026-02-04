import 'package:flutter/material.dart';

class AppToast {
  /// ✅ 기본 성공/정보 알림
  static void show(BuildContext context, String message) {
    _showSnackBar(context, message, backgroundColor: const Color(0xFF2D2D2D));
  }

  /// ❌ 에러/경고 알림
  static void error(BuildContext context, String message) {
    _showSnackBar(
      context,
      message,
      backgroundColor: const Color(0xFFE53935), // 세련된 레드
      isError: true,
    );
  }

  /// 🎨 내부 공통 로직 (하단 꽉 차는 디자인)
  static void _showSnackBar(
    BuildContext context,
    String message, {
    required Color backgroundColor,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        behavior: SnackBarBehavior.fixed, // ✅ 하단에 딱 붙어 꽉 차는 형태
        backgroundColor: backgroundColor,
        elevation: 10,
        // 상단에만 곡선을 주어 바텀 시트 느낌 강조
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
