import 'package:flutter/material.dart';

class AppColors {
  // =========================
  // 🎨 Base
  // =========================
  static const background = Color(0xFFFFFFFF); // 전체 배경
  static const surface = Color(0xFFFFFFFF); // 카드 / 컨테이너
  static const border = Color(0xFFE5E5E5); // 테두리 / 구분선
  static const divider = Color(0xFFF0F0F0);

  // =========================
  // ✍️ Text
  // =========================
  static const textPrimary = Color(0xFF000000); // 메인 텍스트
  static const textSecondary = Color(0xFF8C8C8C); // 설명 / 보조
  static const textDisabled = Color(0xFFBDBDBD);

  static const textColor01 = Color(0xFF222222); // 폰트색상
  static const textColor02 = Color(0xFFFFFFFF); // 폰트색상
  static const textColor03 = Color(0xFF666666); // 폰트색상
  static const textColor04 = Color(0xFFCBCBCB); // 폰트색상
  static const textColor05 = Color(0xFF424242); // 폰트색상
  static const textColor06 = Color(0xFFBCBCBC); // 폰트색상

  // =========================
  // 🌈 login
  // =========================
  static const inputBg = Color(0xFFF3F3F3); // 입력창 배경색
  static const inputText = Color(0xFF222222); // 입력창 글자색
  static const buttonBg = Color(0xffffffff); // 버튼 배경색
  static const buttonBorder = Color(0xffD7D7D7); // 버튼 배경색

  // =========================
  // 🌈 Brand / Accent
  // =========================
  static const primary = Color(0xFF289AEB); // 여행 하늘색
  static const accent = Color(0xFFEA6AA3); // 감성 포인트

  static const onPrimary = Color(0xFFFFFFFF);
  static const onAccent = Color(0xFFFFFFFF);

  // =========================
  // 🚦 State
  // =========================
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFFB300);
  static const error = Color(0xFFEB5757);

  // =========================
  // 🎈 Decorative (Login / Background Shapes)
  // =========================
  static const decoMint = Color(0xFF8EE6C4);
  static const decoOrange = Color(0xFFF6A45C);
  static const decoYellow = Color(0xFFFFE99C);
  static const decoPurple = Color(0xFF9B8CF2);

  // =========================
  // 🌫 Overlay / Shadow
  // =========================
  static const overlay = Color(0x1A000000); // 아주 연한 오버레이
  static const shadow = Color(0x14000000); // 카드 그림자

  // 🔐 Login Buttons
  static const kakaoYellow = Color(0xFFFEE500);
  static const appleBlack = Color(0xFF000000);
  static const googleBorder = Color(0xFFE0E0E0);

  // =========================
  // 🌤 Light UI (피그마 기준)
  // =========================
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);

  // 배경
  static const lightBackground = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFEEEEEE);
  static const lightDivider = Color(0xFFE5E5E5);
  static const lightGrayBackground = Color(0xFFF6F6F6);

  // 텍스트 (라이트)
  static const lightTextPrimary = Color(0xFF111111);
  static const lightTextSecondary = Color(0xFF777777);
  static const lightTextDisabled = Color(0xFFBDBDBD);

  // =========================
  // 🧳 Home 상태 카드
  // =========================
  static const travelActiveBlue = Color(0xFF289AEB); // 여행 중 (피그마 파랑)
  static const travelInactiveGray = Color(0xFFA8A8A8); // 여행 준비 중

  // 홈 여행 상태
  static const travelingBlue = Color(0xFF289AEB); // 피그마 파랑
  static const travelReadyGray = Color(0xFFA8A8A8); // 피그마 회색
  static const travelingPurple = Color(0xFF7C5FF6); // 피그마 보라

  // =========================
  // 🗺 Map / Tab
  // =========================
  static const tabBackground = Color(0xFFF3F3F3); // 탭 전체 배경
  static const tabSelected = Color(0xFF19C6E3); // 한국 선택 (피그마 파랑)
  static const tabText = Color(0xFF8E8E8E); // 미선택 텍스트
  static const tabSelectedText = Colors.white;

  // =========================
  // 📜 Map Vintage (Parchment 스타일 전용)
  // =========================
  static const mapVintageBackground = Color(0xFFF5E6D3); // 양피지 기본 배경색
  static const mapVisitedFill = Color.fromARGB(
    255,
    189,
    110,
    14,
  ); // 방문 지역 (오래된 황토색 인장 느낌)
  static const mapOverseaVisitedFill = Color.fromARGB(
    255,
    188,
    68,
    162,
  ); // 방문 지역 (오래된 황토색 인장 느낌)
  static const mapVisitedBorder = Color(0xFF5D4037); // 방문 지역 테두리 (진한 갈색 잉크)
  static const mapTextInk = Color(0xFF3E2723); // 지도 위 텍스트용 잉크색
}
