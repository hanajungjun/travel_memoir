import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:easy_localization/easy_localization.dart';

class TravelCompletionPage extends StatefulWidget {
  final Future<void> processingTask;
  final RewardedAd? rewardedAd;

  const TravelCompletionPage({
    super.key,
    required this.processingTask,
    this.rewardedAd,
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

      if (widget.rewardedAd != null) {
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

        debugPrint("📺 [AD-COMPLETE] 여행 완료 광고 노출 시작");
        await widget.rewardedAd!.show(
          onUserEarnedReward: (ad, reward) => debugPrint("🎁 보상 확인"),
        );
        await adCompleter.future;
      }
      await backgroundTask;
    } catch (e) {
      debugPrint("❌ 작업 중 오류: $e");
    } finally {
      // 모든 작업이 끝나도 화면이 메인으로 이동
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/travel_info', (route) => false);
      }

      debugPrint("🔔 [TEST] 모든 작업 완료! 주석 처리로 인해 메인 이동은 하지 않습니다.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity, // 부모 너비를 꽉 채우게 설정
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // 세로 중앙 정렬
          crossAxisAlignment: CrossAxisAlignment.center, // 가로 중앙 정렬
          children: [
            Lottie.asset(
              'assets/lottie/travel_success.json',
              width: 250,
              height: 250, // 높이 추가
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
            // 하단에 로딩 인디케이터 하나 더 두면 심심하지 않아요.
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
