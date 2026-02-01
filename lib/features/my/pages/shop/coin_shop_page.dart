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
  bool _isPremium = false; // ✅ [추가] 프리미엄 여부 상태

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

    if (mounted) {
      setState(() {
        _adUsedToday = used;
        _adDailyLimit = (reward['daily_limit'] ?? 0).toInt();
        _adDate = today;
      });
    }
  }

  Future<void> _fetchOfferings() async {
    try {
      Offerings? offerings = await PaymentService.getOfferings();
      // ✅ [추가] 현재 유저의 프리미엄 상태도 함께 가져옴
      final customerInfo = await Purchases.getCustomerInfo();

      if (offerings?.current != null) {
        final allPackages = offerings!.current!.availablePackages;
        setState(() {
          _isPremium =
              customerInfo.entitlements.all["TravelMemoir Pro"]?.isActive ??
              false;
          //2️⃣ 강제로 false를 넣어 일반 유저 상태를 만듭니다.
          //_isPremium = false;
          _subscriptionPackages = allPackages
              .where(
                (p) =>
                    p.packageType == PackageType.monthly ||
                    p.packageType == PackageType.annual,
              )
              .toList();
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
    setState(() {
      _isProductsLoading = true;
    });

    try {
      if (await PaymentService.purchasePackage(package)) {
        await Future.delayed(const Duration(seconds: 1));

        // 결제 성공 후 상태 업데이트 (프리미엄 여부 포함)
        await _fetchOfferings();
        final newBalance = _fetchCoinBalances();

        if (mounted) {
          setState(() {
            _balanceFuture = newBalance;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('upgrade_success_msg'.tr())));
        }
      }
    } catch (e) {
      debugPrint('❌ 결제 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProductsLoading = false;
        });
      }
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
          setState(() {
            _balanceFuture = newBalance;
          });
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
    setState(() {
      _isProductsLoading = true;
    });

    try {
      await PaymentService.restorePurchases();
      await _fetchOfferings(); // 복원 후 프리미엄 상태 갱신
      final newBalance = _fetchCoinBalances();

      if (mounted) {
        setState(() {
          _balanceFuture = newBalance;
        });
      }
    } catch (e) {
      debugPrint('❌ 복원 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProductsLoading = false;
        });
      }
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBalanceCard(),
                  const SizedBox(height: 10),

                  // ✅ [개선] 구독 중일 때와 아닐 때의 화면 분기
                  Text(
                    'membership_plan'.tr(),
                    style: AppTextStyles.sectionTitle,
                  ),
                  const SizedBox(height: 10),

                  if (_isPremium)
                    _buildSubscribedCard() // ⭐ 구독 중이면 전용 카드 표시
                  else
                    ..._subscriptionPackages.map(
                      (p) => _buildSubscriptionCard(
                        title: p.storeProduct.title,
                        price: p.storeProduct.priceString,
                        period: _packagePeriodLabel(context, p),
                        benefits: [
                          'benefit_stickers'.tr(),
                          'benefit_ai_picker'.tr(),
                          'benefit_monthly_coins'.tr(),
                          'benefit_ai_extra_image'.tr(),
                        ],
                        onTap: () => _handlePurchase(p),
                      ),
                    ),

                  const SizedBox(height: 2),
                  Text('charge_coins'.tr(), style: AppTextStyles.sectionTitle),
                  const SizedBox(height: 8),
                  _buildCoinGrid(),
                  Center(
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
                  _buildFooterNotice(),
                ],
              ),
            ),
    );
  }

  // ✅ 이미 구독 중일 때 보여줄 카드 UI
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
                'premium_member_active'.tr(), // "프리미엄 혜택을 이용 중입니다"
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
            'premium_thanks_msg'.tr(), // "감사합니다! 모든 기능을 마음껏 즐기세요."
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
              const Divider(height: 24),
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
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$price $period',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: benefits
                    .map(
                      (b) => Text(
                        b,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    )
                    .toList(),
              ),
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

  Widget _buildFooterNotice() {
    return Center(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'subscription_notice'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTextLink(
                'terms_of_use'.tr(),
                () => _openLegalPage('terms'),
              ),
              const Text(
                '  |  ',
                style: TextStyle(color: Colors.grey, fontSize: 10),
              ),
              _buildTextLink(
                'privacy_policy'.tr(),
                () => _openLegalPage('policy'),
              ),
            ],
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
          fontSize: 10,
          color: Colors.blueGrey,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
