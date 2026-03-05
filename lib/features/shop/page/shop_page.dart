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
  // Entitlement ID (PaymentService에 정의된 것과 동일해야 함)
  static const String _proEntitlementId = "PREMIUM ACCESS";
  //static const String _vipEntitlementId = "VIP_ACCESS";

  late Future<Map<String, int>> _balanceFuture;

  // 🎯 리워드 설정
  int _adUsedToday = 0;
  int _adDailyLimit = 5;
  int _vipDailyAmount = 50;
  String _adRewardMsg = '';
  String _adDate = '';

  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;

  // 🎊 폭죽 컨트롤러
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

  // ==========================================
  // ⚙️ 데이터 로드 로직
  // ==========================================

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

      // 1. 타임아웃 설정 (최대 30초 대기)
      Offerings? offerings = await PaymentService.getOfferings().timeout(
        const Duration(seconds: 30),
      );

      final customerInfo = await Purchases.getCustomerInfo().timeout(
        const Duration(seconds: 30),
      );

      if (mounted) {
        setState(() {
          // ✅ VIP와 Premium 권한을 각각 체크 (PaymentService에 정의된 ID 사용)
          // 만약 클래스 내에 변수가 없다면 직접 문자열 "VIP_ACCESS", "PREMIUM ACCESS"를 넣으셔도 됩니다.
          _isVip = customerInfo.entitlements.all[""]?.isActive ?? false;
          _isPremium =
              customerInfo.entitlements.all["PREMIUM ACCESS"]?.isActive ??
              false;

          if (offerings?.current != null) {
            final allPackages = offerings!.current!.availablePackages;

            // 2. 패키지 분류 로직
            _subscriptionPackages = allPackages.where((p) {
              final id = p.identifier.toLowerCase();
              return p.packageType == PackageType.monthly ||
                  p.packageType == PackageType.annual ||
                  id.contains('vip');
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
          } else {
            debugPrint("⚠️ No current offerings found");
            AppToast.show(context, "Failed to load products.");
          }

          // ✅ 모든 데이터 처리가 끝난 후 로딩 종료
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

  // ==========================================
  // 🎬 광고 로직
  // ==========================================

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

    // 1. 일일 한도 초과
    if (_adUsedToday >= _adDailyLimit) {
      AppToast.error(context, 'ad_limit_reached'.tr());
      return;
    }

    // 2. 광고 아직 로드 중
    if (!_isAdLoaded || _rewardedAd == null) {
      AppToast.show(context, 'ad_not_ready_desc'.tr()); // 👈 다이얼로그 대신 토스트로
      _loadAds(); // 다시 로드 시도
      return;
    }

    // 3. 광고 표시
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isAdLoaded = false;
        _loadAds(); // 다음 광고 미리 로드
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

  // ==========================================
  // 💰 결제 핸들링 (에러 수정 완료 ✅)
  // ==========================================
  Future<void> _handlePurchase(Package package) async {
    // 1. 로딩 시작
    setState(() {
      _isProductsLoading = true;
    });

    try {
      // 2. 결제 요청 (setState 밖에서 처리)
      bool success = await PaymentService.purchasePackage(package);

      if (success) {
        // 3. 서버 데이터 동기화 및 최신 정보 수집
        await PaymentService.syncSubscriptionStatus();
        await _fetchOfferings();
        final newFuture = _fetchCoinBalances();

        if (mounted) {
          // 🚨 [핵심] 결제 후 웹훅/DB 업데이트 시간을 위해 잠깐 대기
          await Future.delayed(const Duration(milliseconds: 1000));
          // 4. 상태 업데이트 (동기적으로 수행)
          setState(() {
            _balanceFuture = newFuture;
            _isProductsLoading = false; // 로딩 종료를 같이 처리
          });

          // 🎊 폭죽 발사
          _confettiController.play();

          // AppDialogs.showDynamicIconAlert(
          //   context: context,
          //   title: 'congratulations'.tr(),
          //   message: 'upgrade_success_msg'.tr(),
          //   icon: Icons.celebration,
          //   iconColor: AppColors.primary,
          //   onClose: () {
          //     Navigator.of(context).popUntil((route) => route.isFirst);
          //   },
          // );
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

  // ==========================================
  // 🎨 UI 빌더
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final bool adDisabled = _adUsedToday >= _adDailyLimit;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA), // 연한 배경색
      appBar: AppBar(
        title: Text(
          'coin_shop'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF3D3D3D),
        elevation: 0,
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: adDisabled ? null : _handleWatchAdReward,
            child: Text(
              '${'watch_ad_get_coin'.tr()} ($_adUsedToday/$_adDailyLimit)',
              style: TextStyle(
                color: adDisabled ? Colors.grey[500] : const Color(0xFFFFD54F),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _isProductsLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── 상단 다크 헤더 영역 (잔액 카드 포함) ───
                      _buildBalanceHeader(),

                      const SizedBox(height: 24),

                      // ─── 멤버십 플랜 섹션 ───
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'membership_plan'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF222222),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSubscriptionSection(),

                      const SizedBox(height: 24),

                      // ─── 티켓 충전하기 섹션 ───
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'charge_coins'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF222222),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildCoinGrid(),
                      ),

                      const SizedBox(height: 20),

                      // ─── 복원 버튼 ───
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _handleRestore,
                          icon: const Icon(
                            Icons.restore,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: Text(
                            'restore'.tr(),
                            style: const TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC8C8C8),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),

                      _buildFooterNotice(),
                      SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 16,
                      ),
                    ],
                  ),
                ),

          // ✨ 브랜드 컬러 폭죽 위젯
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

  // ─── 상단 다크 헤더 위젯 (이미지 스타일 반영) ───
  Widget _buildBalanceHeader() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF3D3D3D),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: FutureBuilder<Map<String, int>>(
        future: _balanceFuture,
        builder: (context, snapshot) {
          final free = snapshot.data?['free'] ?? 0;
          final paid = snapshot.data?['paid'] ?? 0;
          return Row(
            children: [
              Expanded(
                child: _buildBalanceTile(
                  label: 'free_stamp'.tr(),
                  value: free.toString().padLeft(4, '0'),
                  valueColor: const Color(0xFF4FC3F7), // 이미지의 블루 톤
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBalanceTile(
                  label: 'paid_stamp'.tr(),
                  value: paid.toString().padLeft(4, '0'),
                  valueColor: const Color(0xFFFFD54F), // 이미지의 골드 톤
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBalanceTile({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF4A4A4A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionSection() {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _subscriptionPackages.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final p = _subscriptionPackages[index];
          final bool isVip = p.identifier.toLowerCase().contains('vip');
          return SizedBox(
            width: MediaQuery.of(context).size.width * 0.75,
            child: _buildSubscriptionCard(
              title: p.storeProduct.title,
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
  }) {
    final List<Color> gradientColors = isVip
        ? [const Color(0xFF917BFF), const Color(0xFF6B4BFF)] // VIP/연간용 퍼플
        : [const Color(0xFF4A90D9), const Color(0xFF357ABD)]; // 월간구독용 블루

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradientColors.last.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$title ($price $period)',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
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
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) {
        final p = _coinPackages[index];
        return GestureDetector(
          onTap: () => _handlePurchase(p),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.confirmation_num_outlined,
                  color: Color(0xFF666666),
                  size: 24,
                ),
                const SizedBox(height: 8),
                Text(
                  p.storeProduct.title.split('(').first.trim(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p.storeProduct.priceString,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
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
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
      child: Column(
        children: [
          if (Platform.isIOS) ...[
            Text(
              'subscription_notice'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[400],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
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
                height: 10,
                color: Colors.grey[300],
              ),
              _buildTextLink(
                'privacy_policy'.tr(),
                () => _openLegalPage('policy'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '© 2026 Travel Memoir.',
            style: TextStyle(fontSize: 9, color: Colors.grey[400]),
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

  String _packagePeriodLabel(BuildContext context, Package package) {
    final isKorean = context.locale.languageCode == 'ko';
    if (package.identifier.toLowerCase().contains('vip'))
      return isKorean ? '/ 연' : 'per Year';
    switch (package.packageType) {
      case PackageType.monthly:
        return isKorean ? '/ 월' : 'per month';
      case PackageType.annual:
        return isKorean ? '/ 연' : 'per Year';
      default:
        return '';
    }
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
