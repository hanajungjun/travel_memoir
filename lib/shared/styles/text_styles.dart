import 'package:flutter/material.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';

class AppTextStyles {
  // =========================
  // 🎬 Intro / Hero
  // =========================
  static const introMain = TextStyle(
    fontFamily: 'Noto Sans',
    color: AppColors.primary,
    fontSize: 45,
    fontWeight: FontWeight.w100,
    height: 1.1,
  );

  static const introSub = TextStyle(
    fontFamily: 'Noto Sans',
    color: AppColors.accent,
    fontSize: 45,
    fontWeight: FontWeight.w600,
    height: 1.1,
  );

  // =========================
  // 🏷 Titles
  // =========================
  static const title = TextStyle(
    fontFamily: 'Noto Sans',
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const sectionTitle = TextStyle(
    fontFamily: 'Noto Sans',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const appBarTitle = TextStyle(
    fontFamily: 'Noto Sans',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // =========================
  // ✍️ Body
  // =========================
  static const body = TextStyle(
    fontFamily: 'Noto Sans',
    fontSize: 16,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const bodyMuted = TextStyle(
    fontFamily: 'Noto Sans',
    fontSize: 14,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static const caption = TextStyle(
    fontFamily: 'Noto Sans',
    fontSize: 12,
    color: AppColors.textDisabled,
  );

  // =========================
  // 🔘 Button
  // =========================
  static const button = TextStyle(
    fontFamily: 'Noto Sans',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
}
