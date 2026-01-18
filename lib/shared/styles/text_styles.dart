import 'package:flutter/material.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';

class AppTextStyles {
  // =====================================================
  // 🧭 Landing / Login (Figma 기준)
  // =====================================================
  static const TextStyle landingTitle = TextStyle(
    fontSize: 35,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.25, // 줄간격 고정
    letterSpacing: -1.5,
  );

  static const TextStyle landingSubtitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w300,
    color: AppColors.textSecondary,
    height: 1.5, // 줄간격 고정
    letterSpacing: -0.3,
  );

  static const TextStyle loginButton = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // =====================================================
  // 🧭 Page / Section
  // =====================================================
  static const TextStyle pageTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w800,
    color: AppColors.textColor02,
    letterSpacing: -0.3,
  );

  static const TextStyle sectionText = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w100,
    color: AppColors.textColor02,
    letterSpacing: -0.5,
  );

  // =====================================================
  // ✍️ Body
  // =====================================================
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMuted = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static const TextStyle bodyDisabled = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textDisabled,
  );

  // =====================================================
  // 🔘 Button (Theme용)
  // =====================================================
  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.onPrimary,
  );

  static const TextStyle buttonOutline = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // =====================================================
  // 🏷 Small / Meta
  // =====================================================
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // =========================
  // 🧳 Home 상태 카드
  // =========================
  static const statusTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const statusSubtitle = TextStyle(fontSize: 14, color: Colors.white70);
}
