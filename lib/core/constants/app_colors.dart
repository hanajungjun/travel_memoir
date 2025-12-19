import 'package:flutter/material.dart';

class AppColors {
  // =========================
  // 🎨 Base
  // =========================
  static const background = Color(0xFF19150B); // 전체 배경 (다크)
  static const surface = Color(0xFF221D12); // 카드 / 컨테이너 배경
  static const divider = Color(0xFF2F2A1E); // 구분선

  // =========================
  // ✍️ Text
  // =========================
  static const textPrimary = Color(0xFFFFFFFF); // 기본 텍스트
  static const textSecondary = Color(0xFFB8B4A8); // 보조 텍스트
  static const textDisabled = Color(0xFF6F6B5E); // 비활성

  // =========================
  // 🌈 Accent / Brand
  // =========================
  static const primary = Color(0xFF11D1EA); // 메인 포인트 (하늘/여행)
  static const accent = Color(0xFFEA6AA3); // 감성 포인트 (일기/기억)

  // 👉 on-color (버튼/탭 위 텍스트용)
  static const onPrimary = Color(0xFF19150B); // primary 위 글자색
  static const onAccent = Color(0xFFFFFFFF); // accent 위 글자색

  // =========================
  // 🚦 State
  // =========================
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFFB300);
  static const error = Color(0xFFE53935);

  // =========================
  // 🌫 Overlay / Shadow (UX용)
  // =========================
  static const overlay = Color(0x66000000); // 이미지 위 오버레이
  static const shadow = Color(0x55000000); // 카드 그림자
}
