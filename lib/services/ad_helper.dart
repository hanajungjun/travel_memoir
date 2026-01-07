// import 'package:google_mobile_ads/google_mobile_ads.dart';

// class AdHelper {
//   RewardedAd? _rewardedAd;

//   // 테스트용 보상형 광고 ID (구글 제공 공통 ID)
//   // 실제 배포 시에는 AdMob 홈페이지에서 발급받은 ID로 바꿔야 합니다.
//   static String get rewardedAdUnitId =>
//       'ca-app-pub-3940256099942544/5224354917';

//   // 광고 미리 로드해두기
//   void loadRewardedAd({required Function onAdLoaded}) {
//     RewardedAd.load(
//       adUnitId: rewardedAdUnitId,
//       request: const AdRequest(),
//       rewardedAdLoadCallback: RewardedAdLoadCallback(
//         onAdLoaded: (ad) {
//           _rewardedAd = ad;
//           onAdLoaded();
//         },
//         onAdFailedToLoad: (error) {
//           print('광고 로드 실패: $error');
//         },
//       ),
//     );
//   }

//   // 광고 보여주기
//   void showRewardedAd({required Function onRewardEarned}) {
//     if (_rewardedAd == null) {
//       print('광고가 아직 준비되지 않았습니다.');
//       return;
//     }

//     _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
//       onAdDismissedFullScreenContent: (ad) {
//         ad.dispose();
//         loadRewardedAd(onAdLoaded: () {}); // 다음을 위해 미리 로드
//       },
//     );

//     _rewardedAd!.show(
//       onUserEarnedReward: (ad, reward) {
//         onRewardEarned(); // 사용자가 광고를 끝까지 봤을 때 실행할 함수
//       },
//     );
//   }
// }
