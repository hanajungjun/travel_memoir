import 'dart:io';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/services/payment_service.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/services/stamp_service.dart';

class CoinShopPage extends StatefulWidget {
  const CoinShopPage({super.key});

  @override
  State<CoinShopPage> createState() => _CoinShopPageState();
}

class _CoinShopPageState extends State<CoinShopPage> {
  List<Package> _subscriptionPackages = [];
  List<Package> _coinPackages = [];
  bool _isProductsLoading = true;
  bool _isPremium = false;

  late Future<Map<String, int>> _balanceFuture;

  int _adUsedToday = 0;
  int _adDailyLimit = 0;
  String _adDate = '';

  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;

  final StampService _stampService = StampService();

  @override
  void initState() {
    super.initState();
    _balanceFuture = _fetchCoinBalances();
    _fetchOfferings();
    _loadAds();
    _loadAdRewardStatus();
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }

  void _openLegalPage(String type) {
    final isKorean = context.locale.languageCode == 'ko';
    final suffix = isKorean ? '' : '_en';
    String baseUrl = 'https://hanajungjun.github.io/travel-memoir-docs/';
    String fileName = (type == 'terms') ? 'terms' : 'index';
    _launchUrl('$baseUrl$fileName$suffix.html');
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      try {
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        debugPrint('❌ URL 실행 에러: $e');
      }
    }
  }

  String _packagePeriodLabel(BuildContext context, Package package) {
    final isKorean = context.locale.languageCode == 'ko';
    if (package.identifier.toLowerCase().contains('vip') ||
        package.identifier.toLowerCase().contains('777')) {
      return isKorean ? '/ 1년 PASS' : 'per Year';
    }
    switch (package.packageType) {
      case PackageType.monthly:
        return isKorean ? '/ 월' : 'per month';
      case PackageType.annual:
        return isKorean ? '/ 연' : 'per year';
      default:
        return '';
    }
  }

  Future<Map<String, int>> _fetchCoinBalances() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return {'free': 0, 'paid': 0};
    final res = await Supabase.instance.client
        .from('users')
        .select('daily_stamps, paid_stamps')
        .eq('auth_uid', user.id)
        .single();
    return {
      'free': (res['daily_stamps'] ?? 0).toInt(),
      'paid': (res['paid_stamps'] ?? 0).toInt(),
    };
  }

  Future<void> _loadAdRewardStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final userData = await _stampService.getStampData(user.id);
    final reward = await _stampService.getRewardConfig('ad_watch_stamp');
    if (userData == null || reward == null) return;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    int used = (userData['ad_reward_count'] ?? 0).toInt();
    if (userData['ad_reward_date'] != today) used = 0;
    if (mounted)
      setState(() {
        _adUsedToday = used;
        _adDailyLimit = (reward['daily_limit'] ?? 0).toInt();
        _adDate = today;
      });
  }

  Future<void> _fetchOfferings() async {
    try {
      Offerings? offerings = await PaymentService.getOfferings();
      final customerInfo = await Purchases.getCustomerInfo();
      if (offerings?.current != null) {
        final allPackages = offerings!.current!.availablePackages;
        setState(() {
          _isPremium =
              customerInfo.entitlements.all["TravelMemoir Pro"]?.isActive ??
              false;
          _isPremium = false; // 테스트용

          _subscriptionPackages = allPackages.where((p) {
            final id = p.identifier.toLowerCase();
            return p.packageType == PackageType.monthly ||
                p.packageType == PackageType.annual ||
                id.contains('vip') ||
                id.contains('777');
          }).toList();

          _subscriptionPackages.sort(
            (a, b) => a.storeProduct.price.compareTo(b.storeProduct.price),
          );
          _coinPackages =
              allPackages
                  .where((p) => p.storeProduct.identifier.contains('coin'))
                  .toList()
                ..sort(
                  (a, b) =>
                      a.storeProduct.price.compareTo(b.storeProduct.price),
                );
          _isProductsLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isProductsLoading = false);
    }
  }

  Future<void> _handlePurchase(Package package) async {
    setState(() => _isProductsLoading = true);
    try {
      if (await PaymentService.purchasePackage(package)) {
        await Future.delayed(const Duration(seconds: 1));
        await _fetchOfferings();
        final newBalance = _fetchCoinBalances();
        if (mounted) {
          setState(() => _balanceFuture = newBalance);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('upgrade_success_msg'.tr())));
        }
      }
    } catch (e) {
      debugPrint('❌ 결제 실패: $e');
    } finally {
      if (mounted) setState(() => _isProductsLoading = false);
    }
  }

  void _loadAds() {
    final adId = Platform.isAndroid
        ? 'ca-app-pub-3890698783881393/3553280276'
        : 'ca-app-pub-3890698783881393/4814391052';
    RewardedAd.load(
      adUnitId: adId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdLoaded = true;
        },
        onAdFailedToLoad: (_) {
          _isAdLoaded = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  Future<void> _handleWatchAdReward() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    if (_adUsedToday >= _adDailyLimit) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ad_limit_reached'.tr())));
      return;
    }
    if (!_isAdLoaded || _rewardedAd == null) {
      _showNoAdDialog();
      _loadAds();
      return;
    }
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadAds();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadAds();
        _showNoAdDialog();
      },
    );
    _rewardedAd!.show(
      onUserEarnedReward: (_, __) async {
        final result = await _stampService.grantAdReward(user.id);
        if (result == null) return;
        await _loadAdRewardStatus();
        final newBalance = _fetchCoinBalances();
        if (mounted) {
          setState(() => _balanceFuture = newBalance);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('ad_reward_success'.tr())));
        }
      },
    );
  }

  void _showNoAdDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'ad_not_ready_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('ad_not_ready_desc'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'confirm'.tr(),
              style: const TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRestore() async {
    setState(() => _isProductsLoading = true);
    try {
      await PaymentService.restorePurchases();
      await _fetchOfferings();
      final newBalance = _fetchCoinBalances();
      if (mounted) setState(() => _balanceFuture = newBalance);
    } catch (e) {
      debugPrint('❌ 복원 실패: $e');
    } finally {
      if (mounted) setState(() => _isProductsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool adDisabled = _adUsedToday >= _adDailyLimit;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'coin_shop'.tr(),
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: adDisabled ? null : _handleWatchAdReward,
            child: Text(
              '${'watch_ad_get_coin'.tr()} ($_adUsedToday/$_adDailyLimit)',
              style: TextStyle(
                color: adDisabled ? Colors.grey : Colors.blueAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isProductsLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                10,
                10,
                20,
                10,
              ), // ✅ 하단 패딩 40 -> 20 축소
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBalanceCard(),
                  const SizedBox(height: 12),
                  Text(
                    'membership_plan'.tr(),
                    style: AppTextStyles.sectionTitle,
                  ),
                  const SizedBox(height: 8),

                  if (_isPremium)
                    _buildSubscribedCard()
                  else
                    SizedBox(
                      height: 185,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _subscriptionPackages.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final p = _subscriptionPackages[index];
                          final id = p.identifier.toLowerCase();
                          bool isVip = id.contains('vip');
                          return SizedBox(
                            width: MediaQuery.of(context).size.width * 0.78,
                            child: _buildSubscriptionCard(
                              title: p.storeProduct.title,
                              price: p.storeProduct.priceString,
                              period: _packagePeriodLabel(context, p),
                              benefits: isVip
                                  ? [
                                      'daily_50_ai_generations'.tr(),
                                      'all_premium_features'.tr(),
                                    ]
                                  : [
                                      'benefit_ai_picker'.tr(),
                                      'benefit_monthly_coins'.tr(),
                                      'benefit_ai_extra_image'.tr(),
                                      'complete_removal_of_watermark'.tr(),
                                      'benefit_stickers'.tr(),
                                    ],
                              onTap: () => _handlePurchase(p),
                              isVip: isVip,
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 18), // ✅ 25 -> 18 축소
                  Text('charge_coins'.tr(), style: AppTextStyles.sectionTitle),
                  const SizedBox(height: 8),
                  _buildCoinGrid(),

                  // ✅ 복원 버튼 영역 여백 최소화
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: TextButton(
                        onPressed: _handleRestore,
                        child: Text(
                          'restore'.tr(),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),

                  _buildFooterNotice(), // ✅ 내부 여백 대폭 다이어트
                ],
              ),
            ),
    );
  }

  Widget _buildSubscribedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.stars_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'premium_member_active'.tr(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'premium_thanks_msg'.tr(),
            style: TextStyle(color: Colors.blueGrey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return FutureBuilder<Map<String, int>>(
      future: _balanceFuture,
      builder: (context, snapshot) {
        final free = snapshot.data?['free'] ?? 0;
        final paid = snapshot.data?['paid'] ?? 0;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'free_stamp'.tr(),
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Text(
                    '$free',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'paid_stamp'.tr(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$paid',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubscriptionCard({
    required String title,
    required String price,
    required String period,
    required List<String> benefits,
    required VoidCallback onTap,
    bool isVip = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isVip
              ? [const Color(0xFF1A1A1A), const Color(0xFFC5A028)]
              : [const Color(0xFF2E3192), const Color(0xFF1BFFFF)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isVip
            ? [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          // ✅ [다이어트] 상하 패딩을 16 -> 12로 줄여 공간 확보
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            // ✅ [핵심] 위쪽으로 바짝 붙여서 바닥 공간을 확보합니다.
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (isVip)
                    const Icon(
                      Icons.workspace_premium,
                      color: Colors.amber,
                      size: 18, // 살짝 축소
                    ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2), // ✅ 간격 4 -> 2로 축소
              Text(
                '$price $period',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              // ✅ [다이어트] 디바이더 높이를 16 -> 12로 축소
              const Divider(color: Colors.white24, height: 14),

              // ✅ [범인 검거] .take(4)를 삭제하여 모든 혜택(5개 이상)이 나오게 수정
              ...benefits
                  .map(
                    (b) => Padding(
                      // ✅ 줄 간격을 3 -> 2.5로 미세 조정
                      padding: const EdgeInsets.only(bottom: 2.5),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: isVip ? Colors.amber[200] : Colors.white70,
                            size: 10,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              b,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                height: 1.1, // 줄 간격 촘촘하게
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoinGrid() {
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _coinPackages.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        final p = _coinPackages[index];
        return InkWell(
          onTap: () => _handlePurchase(p),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stars, color: Colors.amber, size: 20),
                const SizedBox(height: 4),
                Text(
                  p.storeProduct.title.split('(').first.trim(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  p.storeProduct.priceString,
                  style: TextStyle(color: AppColors.primary, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ✅ [강조] 하단 영역 다이어트 (Ocean -> Pond 수준으로 압축)
  Widget _buildFooterNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 5,
        horizontal: 10,
      ), // ✅ 20 -> 5 대폭 축소
      child: Column(
        children: [
          Text(
            'subscription_notice'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8), // ✅ 15 -> 8 축소
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTextLink(
                'terms_of_use'.tr(),
                () => _openLegalPage('terms'),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 1,
                height: 8,
                color: Colors.grey[300],
              ),
              _buildTextLink(
                'privacy_policy'.tr(),
                () => _openLegalPage('policy'),
              ),
            ],
          ),
          const SizedBox(height: 6), // ✅ 10 -> 6 축소
          Text(
            '© 2026 Travel Memoir.',
            style: TextStyle(fontSize: 9, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildTextLink(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.blueGrey,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
