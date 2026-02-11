import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:easy_localization/easy_localization.dart';

/**
 * 📱 Screen ID : TRAVEL_COMPLETION_PAGE
 * 📝 Name      : 여행 완료 처리 대기 화면
 * 🛠 Feature   : 
 * - 여행 종료 로직(TravelCompleteService) 실행 및 대기
 * - VIP 유무 및 유료 코인 사용 여부에 따른 보상 광고(AdMob) 노출 제어
 * - 완료 후 메인 탭(/travel_info)으로 스택 초기화 및 이동
 * * [ UI Structure ]
 * ----------------------------------------------------------
 * travel_completion_page.dart (Scaffold)
 * └── Center (Body)
 * └── Column
 * ├── Lottie.asset [travel_success 애니메이션]
 * ├── Text [완료 처리 중 문구]
 * └── CircularProgressIndicator [진행 상태 인디케이터]
 * ----------------------------------------------------------
 */

class TravelCompletionPage extends StatefulWidget {
  final Future<void> processingTask;
  final RewardedAd? rewardedAd;
  final bool usedPaidStamp;
  final bool isVip; // ✅ [추가] VIP 여부 파라미터

  const TravelCompletionPage({
    super.key,
    required this.processingTask,
    this.rewardedAd,
    required this.usedPaidStamp,
    required this.isVip, // ✅ 필수 값으로 추가
  });

  @override
  State<TravelCompletionPage> createState() => _TravelCompletionPageState();
}

class _TravelCompletionPageState extends State<TravelCompletionPage> {
  @override
  void initState() {
    super.initState();
    _startParallelProcess();
  }

  Future<void> _startParallelProcess() async {
    try {
      final Future<void> backgroundTask = widget.processingTask;
      await Future.delayed(const Duration(milliseconds: 100));

      // ✅ [핵심 로직 수정]
      // 1. VIP가 아니고 (!isVip)
      // 2. 유료 코인을 쓰지 않았고 (!usedPaidStamp)
      // 3. 광고가 준비되어 있다면
      // -> 이때만 광고를 보여줍니다. 즉, VIP는 무조건 PASS!
      if (!widget.isVip && !widget.usedPaidStamp && widget.rewardedAd != null) {
        final adCompleter = Completer<void>();

        widget.rewardedAd!.fullScreenContentCallback =
            FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                if (!adCompleter.isCompleted) adCompleter.complete();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                if (!adCompleter.isCompleted) adCompleter.complete();
              },
            );

        await widget.rewardedAd!.show(onUserEarnedReward: (_, __) {});

        await adCompleter.future;
      }

      await backgroundTask;
    } finally {
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/travel_info', (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/lottie/travel_success.json',
              width: 250,
              height: 250,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 30),
            Text(
              'completing_travel_loading'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'please_wait_moment'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 15),
            ),
            const SizedBox(height: 50),
            const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
            ),
          ],
        ),
      ),
    );
  }
}
