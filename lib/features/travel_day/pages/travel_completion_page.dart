import 'dart:async';
import 'dart:io';
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
iOS 병렬 흐름
 ├── _showAd() ──────────────────────────┐
 │   (광고 보는 동안)                      │
 └── processingTask() ──────────────────┤
     (AI 커버 생성 동시에)                  │
                                    둘 다 끝나면
                                         ↓
                                  /travel_info 이동

 Android 직렬 흐름   
 시작
 ↓
_showAd() (광고 완전히 끝남)
 ↓
300ms 대기 (lifecycle 안정화)
 ↓
processingTask() (AI 커버 생성)
 ↓
/travel_info 이동                              
*/

class TravelCompletionPage extends StatefulWidget {
  final Future<void> Function() processingTask; // ✅ Function()으로 변
  final RewardedAd? rewardedAd;
  final bool usedPaidStamp;
  final bool isVip;

  const TravelCompletionPage({
    super.key,
    required this.processingTask,
    this.rewardedAd,
    required this.usedPaidStamp,
    required this.isVip,
  });

  @override
  State<TravelCompletionPage> createState() => _TravelCompletionPageState();
}

class _TravelCompletionPageState extends State<TravelCompletionPage> {
  @override
  void initState() {
    super.initState();
    _startProcess();
  }

  Future<void> _startProcess() async {
    try {
      if (!widget.isVip && !widget.usedPaidStamp && widget.rewardedAd != null) {
        if (Platform.isIOS) {
          // ✅ iOS: 광고 + task 병렬
          await Future.wait([_showAd(), widget.processingTask()]);
        } else {
          // ✅ Android: 광고 먼저 → task 직렬
          await _showAd();
          await Future.delayed(const Duration(milliseconds: 300));
          await widget.processingTask();
        }
      } else {
        // VIP or 유료코인: 광고 없이 바로 task
        await widget.processingTask();
      }
    } catch (e) {
      debugPrint('❌ [TravelCompletionPage] 에러: $e');
    } finally {
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/travel_info', (_) => false);
      } else {
        debugPrint('💀 [TravelCompletionPage] mounted=false → 네비게이션 스킵');
      }
    }
  }

  Future<void> _showAd() async {
    final completer = Completer<void>();

    // 30초 타임아웃 (광고 무응답 방어)
    Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        debugPrint('⏰ [TravelCompletionPage] 광고 타임아웃 - 강제 진행');
        completer.complete();
      }
    });

    widget.rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('❌ [TravelCompletionPage] 광고 표시 실패: $error');
        ad.dispose();
        if (!completer.isCompleted) completer.complete();
      },
    );
    await widget.rewardedAd!.show(onUserEarnedReward: (_, __) {});
    await completer.future;
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
