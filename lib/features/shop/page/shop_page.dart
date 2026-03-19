import 'dart:io';

import 'dart:math' as Math;

import 'package:flutter/material.dart';

import 'package:easy_localization/easy_localization.dart';

import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:confetti/confetti.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';

import 'package:travel_memoir/services/payment_service.dart';

import 'package:travel_memoir/shared/styles/text_styles.dart';

import 'package:travel_memoir/services/stamp_service.dart';

import 'package:travel_memoir/core/widgets/popup/app_toast.dart';

import 'package:flutter/foundation.dart';

import 'package:flutter_svg/flutter_svg.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  List<Package> _subscriptionPackages = [];

  List<Package> _coinPackages = [];

  bool _isProductsLoading = true;

  bool _isPremium = false;

  bool _isVip = false;

  static const String _proEntitlementId = "PREMIUM ACCESS";

  late Future<Map<String, int>> _balanceFuture;

  int _adUsedToday = 0;

  int _adDailyLimit = 5;

  int _vipDailyAmount = 50;

  String _adRewardMsg = '';

  String _adDate = '';

  RewardedAd? _rewardedAd;

  bool _isAdLoaded = false;

  late ConfettiController _confettiController;

  final StampService _stampService = StampService();

  @override
  void initState() {
    super.initState();

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    _balanceFuture = _fetchCoinBalances();

    _fetchOfferings();

    _loadAds();

    _loadAllConfigs();
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();

    _confettiController.dispose();

    super.dispose();
  }

  Future<void> _loadAllConfigs() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) return;

    final userData = await _stampService.getStampData(user.id);

    final adConfig = await _stampService.getRewardConfig('ad_watch_stamp');

    final vipConfig = await _stampService.getRewardConfig('daily_login_vip');

    if (userData == null) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    int used = (userData['ad_reward_count'] ?? 0).toInt();

    if (userData['ad_reward_date'] != today) used = 0;

    if (mounted) {
      setState(() {
        _adUsedToday = used;

        _adDate = today;

        if (adConfig != null) {
          _adDailyLimit = (adConfig['daily_limit'] ?? 5).toInt();

          _adRewardMsg =
              adConfig['description_${context.locale.languageCode}'] ??
              adConfig['description_ko'] ??
              '';
        }

        if (vipConfig != null) {
          _vipDailyAmount = (vipConfig['reward_amount'] ?? 50).toInt();
        }
      });
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

  Future<void> _fetchOfferings() async {
    try {
      setState(() => _isProductsLoading = true);

      Offerings? offerings = await PaymentService.getOfferings().timeout(
        const Duration(seconds: 30),
      );

      final customerInfo = await Purchases.getCustomerInfo().timeout(
        const Duration(seconds: 30),
      );

      if (mounted) {
        setState(() {
          _isVip = customerInfo.entitlements.all[""]?.isActive ?? false;

          _isPremium =
              customerInfo.entitlements.all["PREMIUM ACCESS"]?.isActive ??
              false;

          if (offerings?.current != null) {
            final allPackages = offerings!.current!.availablePackages;

            _subscriptionPackages = allPackages.where((p) {
              final id = p.identifier.toLowerCase();

              return p.packageType == PackageType.monthly ||
                  p.packageType == PackageType.annual ||
                  id.contains('vip');
            }).toList();

            for (final p in allPackages) {
              debugPrint(
                '📦 package: ${p.identifier}, type: ${p.packageType}, price: ${p.storeProduct.priceString}',
              );
            }

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
          } else {
            debugPrint("⚠️ No current offerings found");

            AppToast.show(context, "Failed to load products.");
          }

          _isProductsLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Shop Load Error: $e");

      if (mounted) {
        setState(() {
          _isProductsLoading = false;
        });

        AppToast.error(context, 'network_error_msg'.tr());
      }
    }
  }

  void _loadAds() {
    final adId = kDebugMode
        ? (Platform.isAndroid
              ? 'ca-app-pub-3940256099942544/6300978111'
              : 'ca-app-pub-3940256099942544/2934735716')
        : (Platform.isAndroid
              ? 'ca-app-pub-3890698783881393/3553280276'
              : 'ca-app-pub-3890698783881393/4814391052');

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
      AppToast.error(context, 'ad_limit_reached'.tr());

      return;
    }

    if (!_isAdLoaded || _rewardedAd == null) {
      AppToast.show(context, 'ad_not_ready_desc'.tr());

      _loadAds();

      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();

        _isAdLoaded = false;

        _loadAds();
      },

      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();

        _isAdLoaded = false;

        _loadAds();

        AppToast.error(context, 'ad_not_ready_desc'.tr());
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (_, __) async {
        final result = await _stampService.grantAdReward(user.id);

        if (result != null && mounted) {
          await _loadAllConfigs();

          setState(() {
            _balanceFuture = _fetchCoinBalances();
          });

          final successMsg = _adRewardMsg.replaceAll(
            '{amount}',

            result['reward_amount'].toString(),
          );

          AppToast.show(context, successMsg);
        }
      },
    );
  }

  Future<void> _handlePurchase(Package package) async {
    setState(() {
      _isProductsLoading = true;
    });

    try {
      bool success = await PaymentService.purchasePackage(package);

      if (success) {
        await PaymentService.syncSubscriptionStatus();

        await _fetchOfferings();

        final newFuture = _fetchCoinBalances();

        if (mounted) {
          await Future.delayed(const Duration(milliseconds: 1000));

          setState(() {
            _balanceFuture = newFuture;

            _isProductsLoading = false;
          });

          _confettiController.play();

          AppToast.show(context, 'upgrade_success_msg'.tr());
        }
      } else {
        if (mounted) setState(() => _isProductsLoading = false);
      }
    } catch (e) {
      debugPrint("❌ 결제 실패: $e");

      if (mounted) setState(() => _isProductsLoading = false);
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isProductsLoading = true);

    try {
      await PaymentService.restorePurchases();

      await _fetchOfferings();

      final newFuture = _fetchCoinBalances();

      setState(() {
        _balanceFuture = newFuture;
      });
    } finally {
      if (mounted) setState(() => _isProductsLoading = false);
    }
  }

  // ✅ identifier에서 숫자 파싱 → 언어에 맞게 타이틀 반환
  // Google Play는 기기 언어 기준으로 title을 반환하므로 앱 언어와 불일치 가능
  String _getCoinTitle(Package p) {
    final isKo = context.locale.languageCode == 'ko';

    final match = RegExp(r'coins_(\d+)').firstMatch(p.storeProduct.identifier);

    final amount = match?.group(1) ?? '';

    if (amount.isEmpty) return p.storeProduct.title.split('(').first.trim();

    return isKo ? '티켓 ${amount}장' : '$amount Tickets';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),

      body: _isProductsLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),

                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),

                    child: Stack(
                      children: [
                        Column(
                          children: [
                            _buildBalanceHeader(),

                            const SizedBox(height: 27),

                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                              ),

                              child: Align(
                                alignment: Alignment.centerLeft,

                                child: Text(
                                  'membership_plan'.tr(),

                                  style: const TextStyle(
                                    fontSize: 14,

                                    fontWeight: FontWeight.w700,

                                    color: Color(0xFF2B2B2B),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            _buildSubscriptionSection(),

                            const SizedBox(height: 26),

                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                              ),

                              child: Align(
                                alignment: Alignment.centerLeft,

                                child: Text(
                                  'charge_coins'.tr(),

                                  style: const TextStyle(
                                    fontSize: 14,

                                    fontWeight: FontWeight.w700,

                                    color: Color(0xFF2B2B2B),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 27,
                              ),

                              child: _buildCoinGrid(),
                            ),

                            const SizedBox(height: 25),

                            Center(
                              child: ElevatedButton(
                                onPressed: _handleRestore,

                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFC2C2C2),

                                  elevation: 0,

                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),

                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,

                                    vertical: 5,
                                  ),
                                ),

                                child: Row(
                                  mainAxisSize: MainAxisSize.min,

                                  children: [
                                    SvgPicture.asset(
                                      'assets/icons/ico_restore.svg',
                                    ),

                                    const SizedBox(width: 5),

                                    Text(
                                      'restore'.tr(),

                                      style: const TextStyle(
                                        color: Colors.white,

                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 15),

                            _buildFooterNotice(),

                            SizedBox(
                              height: MediaQuery.of(context).padding.bottom,
                            ),
                          ],
                        ),

                        Align(
                          alignment: Alignment.topCenter,

                          child: ConfettiWidget(
                            confettiController: _confettiController,

                            blastDirectionality: BlastDirectionality.explosive,

                            shouldLoop: false,

                            colors: [
                              AppColors.primary,

                              AppColors.primary.withOpacity(0.7),

                              const Color(0xFFFFD700),

                              Colors.white,

                              Colors.blueAccent,
                            ],

                            createParticlePath: _drawStar,

                            maxBlastForce: 20,

                            minBlastForce: 8,

                            emissionFrequency: 0.05,

                            numberOfParticles: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Path _drawStar(Size size) {
    double degToRad(double deg) => deg * (Math.pi / 180.0);

    const numberOfPoints = 5;

    final halfWidth = size.width / 2;

    final externalRadius = halfWidth;

    final internalRadius = halfWidth / 2.5;

    final degreesPerStep = degToRad(360 / numberOfPoints);

    final halfDegreesPerStep = degreesPerStep / 2;

    final path = Path();

    final fullAngle = degToRad(360);

    path.moveTo(size.width, halfWidth);

    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(
        halfWidth + externalRadius * Math.cos(step),

        halfWidth + externalRadius * Math.sin(step),
      );

      path.lineTo(
        halfWidth + internalRadius * Math.cos(step + halfDegreesPerStep),

        halfWidth + internalRadius * Math.sin(step + halfDegreesPerStep),
      );
    }

    path.close();

    return path;
  }

  Widget _buildBalanceHeader() {
    final topPadding = MediaQuery.of(context).padding.top;

    final bool adDisabled = _adUsedToday >= _adDailyLimit;

    return Container(
      width: double.infinity,

      color: const Color(0xFF474D51),

      // padding: EdgeInsets.fromLTRB(27, topPadding + 20, 27, 24),
      padding: EdgeInsets.fromLTRB(16, topPadding + 20, 16, 24),

      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,

            children: [
              Text(
                'coin_shop'.tr(),

                style: const TextStyle(
                  color: Colors.white,

                  fontWeight: FontWeight.w700,

                  fontSize: 19,
                ),
              ),

              Align(
                alignment: Alignment.centerRight,

                child: Padding(
                  padding: const EdgeInsets.only(right: 10),

                  child: TextButton(
                    onPressed: adDisabled ? null : _handleWatchAdReward,

                    style: TextButton.styleFrom(padding: EdgeInsets.zero),

                    child: Text(
                      '${'watch_ad_get_coin'.tr()} ($_adUsedToday/$_adDailyLimit)',

                      textAlign: TextAlign.right,

                      style: TextStyle(
                        color: adDisabled
                            ? const Color(0xFF567285)
                            : const Color(0xFF78C7FF),

                        fontWeight: FontWeight.w600,

                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          FutureBuilder<Map<String, int>>(
            future: _balanceFuture,

            builder: (context, snapshot) {
              final free = snapshot.data?['free'] ?? 0;

              final paid = snapshot.data?['paid'] ?? 0;

              return Row(
                children: [
                  Expanded(
                    child: _buildBalanceTile(
                      label: 'free_stamp2'.tr(),

                      value: free.toString().padLeft(4, '0'),

                      valueColor: const Color(0xFF58B5FF),

                      labelColor: const Color(0xFF76C2FF),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: _buildBalanceTile(
                      label: 'paid_stamp2'.tr(),

                      value: paid.toString().padLeft(4, '0'),

                      valueColor: const Color(0xFFFFB338),

                      labelColor: const Color(0xFFFFC870),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceTile({
    required String label,

    required String value,

    required Color valueColor,

    required Color labelColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),

      decoration: BoxDecoration(
        color: const Color(0xFF4E5458),

        borderRadius: BorderRadius.circular(10),

        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [
          // ✅ overflow 방지: Flexible로 감싸서 텍스트 길어져도 안전
          Flexible(
            child: Text(
              label,

              style: TextStyle(color: labelColor, fontSize: 13),

              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(width: 4),

          Text(
            value,

            style: TextStyle(
              color: valueColor,

              fontWeight: FontWeight.w700,

              fontSize: 19,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionSection() {
    return SizedBox(
      height: 230,

      child: ListView.separated(
        scrollDirection: Axis.horizontal,

        padding: const EdgeInsets.symmetric(horizontal: 27),

        itemCount: _subscriptionPackages.length,

        separatorBuilder: (context, index) => const SizedBox(width: 12),

        itemBuilder: (context, index) {
          final p = _subscriptionPackages[index];

          final bool isVip = p.identifier.toLowerCase().contains('vip');

          final bool isAnnual = p.packageType == PackageType.annual;

          return SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,

            child: _buildSubscriptionCard(
              title: _getSubscriptionTitle(p),

              price: p.storeProduct.priceString,

              period: _packagePeriodLabel(context, p),

              benefits: isVip
                  ? [
                      'daily_reward_benefit'.tr().replaceAll(
                        '{amount}',

                        _vipDailyAmount.toString(),
                      ),

                      'benefit_ai_picker'.tr(),

                      'benefit_monthly_coins'.tr(),

                      'benefit_ai_extra_image'.tr(),

                      'complete_removal_of_watermark'.tr(),

                      'benefit_stickers'.tr(),
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

              isAnnual: isAnnual,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubscriptionCard({
    required String title,

    required String price,

    required String period,

    required List<String> benefits,

    required VoidCallback onTap,

    bool isVip = false,

    bool isAnnual = false,
  }) {
    List<Color> gradientColors;

    if (isVip) {
      gradientColors = [const Color(0xFFEE7878), const Color(0xFFBC4646)];
    } else if (isAnnual) {
      gradientColors = [const Color(0xFF977FF6), const Color(0xFF644CC4)];
    } else {
      gradientColors = [const Color(0xFF53ACEF), const Color(0xFF217CBD)];
    }

    return GestureDetector(
      onTap: onTap,

      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,

            end: Alignment.bottomRight,

            colors: gradientColors,
          ),

          borderRadius: BorderRadius.circular(12),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),

              blurRadius: 18,

              offset: const Offset(0, 8),
            ),
          ],
        ),

        child: Padding(
          padding: const EdgeInsets.all(27),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$title ',

                      style: const TextStyle(
                        color: Colors.white,

                        fontWeight: FontWeight.w700,

                        fontSize: 15,
                      ),
                    ),

                    TextSpan(
                      text: ' ($price $period)',

                      style: const TextStyle(
                        color: Color(0xFFFFD700),

                        fontWeight: FontWeight.w800,

                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 9),

              Expanded(
                child: Column(
                  children: benefits
                      .map(
                        (b) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),

                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              const Icon(
                                Icons.check,

                                color: Colors.white,

                                size: 14,
                              ),

                              const SizedBox(width: 6),

                              Expanded(
                                child: Text(
                                  b,

                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),

                                    fontSize: 12,

                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
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

        mainAxisExtent: 100.0,
      ),

      itemBuilder: (context, index) {
        final p = _coinPackages[index];

        return GestureDetector(
          onTap: () => _handlePurchase(p),

          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,

              borderRadius: BorderRadius.circular(12),

              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),

                  blurRadius: 18,

                  offset: const Offset(0, 8),
                ),
              ],
            ),

            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,

              children: [
                SvgPicture.asset('assets/icons/ico_tickets.svg'),

                const SizedBox(height: 6),

                // ✅ identifier 파싱으로 언어 독립적 타이틀 표시
                Text(
                  _getCoinTitle(p),

                  style: const TextStyle(
                    fontWeight: FontWeight.w700,

                    fontSize: 13,
                  ),
                ),

                Text(
                  p.storeProduct.priceString,

                  style: const TextStyle(
                    color: Color(0xFF666666),

                    fontSize: 12,

                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooterNotice() {
    return Container(
      padding: const EdgeInsets.all(25),

      child: Column(
        children: [
          if (Platform.isIOS) ...[
            Text(
              'subscription_notice'.tr(),

              textAlign: TextAlign.center,

              style: const TextStyle(
                fontSize: 11,

                color: Color(0xFFA5A5A5),

                height: 1.4,

                letterSpacing: -0.3,
              ),
            ),

            const SizedBox(height: 10),
          ],

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

                height: 7,

                color: const Color(0xFF2B2B2B).withOpacity(0.9),
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
        if (await canLaunchUrl(url))
          await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('❌ URL 실행 에러: $e');
      }
    }
  }

  String _getSubscriptionTitle(Package p) {
    final isKo = context.locale.languageCode == 'ko';

    final id = p.identifier.toLowerCase();

    if (id.contains('vip')) {
      return 'VIP';
    } else if (p.packageType == PackageType.annual) {
      return isKo ? '연간 구독' : 'Annual Premium';
    } else {
      return isKo ? '월간 구독' : 'Monthly Premium';
    }
  }

  String _packagePeriodLabel(BuildContext context, Package package) {
    final isKorean = context.locale.languageCode == 'ko';

    if (package.identifier.toLowerCase().contains('vip'))
      return isKorean ? '/ 연' : '/ Year';

    switch (package.packageType) {
      case PackageType.monthly:
        return isKorean ? '/ 월' : '/ month';

      case PackageType.annual:
        return isKorean ? '/ 연' : '/ Year';

      default:
        return '';
    }
  }

  Widget _buildTextLink(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,

      child: Text(
        label,

        style: const TextStyle(
          fontSize: 11,

          color: Color(0xFF2B2B2B),

          fontWeight: FontWeight.w400,

          decoration: TextDecoration.underline,

          decorationColor: Color(0xFF2B2B2B),
        ),
      ),
    );
  }
}
