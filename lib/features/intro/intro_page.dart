import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_app/features/daily_word/word_pager_page.dart';
import 'package:my_app/core/constants/app_colors.dart';
import 'package:my_app/shared/styles/text_styles.dart';

class IntroPage extends StatefulWidget {
  static const routeName = '/intro';
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, WordPagerPage.routeName);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start, // ⭐ 글씨 위로 배치
              children: [
                const Text(
                  "나도 예전엔\n오나전 멋진",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.introMain,
                ),

                const SizedBox(height: 10),

                const Text(
                  "X세대였었지..",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.introSub,
                ),

                const SizedBox(height: 60), // ⭐ 글씨 끝 → 이미지까지 충분한 간격

                Image.asset('assets/images/mainCharacter.png', width: 260),
              ],
            ),
          ),

          Positioned(
            right: 24,
            bottom: 24,
            child: Image.asset('assets/images/logo_hj.png', width: 60),
          ),
        ],
      ),
    );
  }
}
