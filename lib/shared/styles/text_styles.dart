import 'package:flutter/material.dart';
import 'package:my_app/core/constants/app_colors.dart';

class AppTextStyles {
  static const introMain = TextStyle(
    fontFamily: 'Noto Sans',
    color: AppColors.textcolor02,
    fontSize: 45,
    fontWeight: FontWeight.w300,
  );

  static const introSub = TextStyle(
    fontFamily: 'Noto Sans',
    color: AppColors.textcolor03,
    fontSize: 45,
    fontWeight: FontWeight.w600,
  );

  static const title = TextStyle(
    fontFamily: 'Noto Sans',
    fontSize: 50,
    color: AppColors.textcolor02,
    fontWeight: FontWeight.w700,
  );

  static const body = TextStyle(
    fontFamily: 'Noto Sans',
    fontSize: 16,
    color: AppColors.textcolor01,
  );

  static const bodyMuted = TextStyle(
    fontFamily: 'Noto Sans',
    fontSize: 14,
    color: AppColors.textcolor03,
  );
}
