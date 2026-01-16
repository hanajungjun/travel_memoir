import 'dart:io'; // ✅ Platform 클래스 사용을 위해 필수
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel_memoir/services/stamp_service.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';

class AdMissionPage extends StatefulWidget {
  const AdMissionPage({super.key});

  @override
  State<AdMissionPage> createState() => _AdMissionPageState();
}

class _AdMissionPageState extends State<AdMissionPage> {
  final StampService _stampService = StampService();
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;
  bool _isProcessing = false;

  String get _userId => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }

  void _loadAds() {
    // 운영 체제에 따른 광고 ID 분기 처리
    final adId = Platform.isAndroid
        ? 'ca-app-pub-3890698783881393/3553280276'
        : 'ca-app-pub-3890698783881393/4814391052';

    RewardedAd.load(
      adUnitId: adId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => setState(() {
          _rewardedAd = ad;
          _isAdLoaded = true;
        }),
        onAdFailedToLoad: (_) => setState(() => _isAdLoaded = false),
      ),
    );
  }

  void _showMissionAd() {
    if (_rewardedAd == null) return;

    setState(() => _isProcessing = true);

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) async {
        // 보상으로 무료 스탬프 지급
        await _stampService.addFreeStamp(_userId, 1);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('ad_reward_msg'.tr())));
          setState(() => _isProcessing = false);
          _loadAds();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'free_charging_station'.tr(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildMissionItem(
                  icon: Icons.play_circle_fill,
                  title: 'mission_watch_ad'.tr(),
                  subtitle: 'mission_reward_desc'.tr(),
                  onTap: _isAdLoaded ? _showMissionAd : null,
                ),
              ],
            ),
    );
  }

  Widget _buildMissionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.travelingBlue, size: 30),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: onTap == null
                  ? Colors.grey
                  : AppColors.travelingBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              'mission_complete_btn'.tr(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
