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
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6), // 연한 배경색
      // 🚨 상단 AppBar 제거
      body: _isProductsLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  // 🎯 [핵심] ClampingScrollPhysics: 화면에 딱 맞으면 스크롤 안 됨
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      // 🎯 최소 높이를 화면 높이와 동일하게 맞춤
                      minHeight: constraints.maxHeight,
                    ),
                    child: Stack(
                      children: [
                        Column(
                          // 👈 SafeArea 바깥으로 Column을 이동시켜 바닥까지 닿게 함
                          children: [
                            // ─── 상단 다크 헤더 영역 (타이틀 + 잔액 카드 포함) ───
                            _buildBalanceHeader(),

                            // 🎯 본문 영역을 수동 배치하여 높이 이슈 방지
                            const SizedBox(height: 27),

                            // ─── 멤버십 플랜 섹션 ───
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

                            // ─── 티켓 충전하기 섹션 ───
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

                            // ─── 복원 버튼 ───
                            Center(
                              child: ElevatedButton(
                                onPressed: _handleRestore, // 👈 기존 로직 유지
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
                                  mainAxisSize:
                                      MainAxisSize.min, // 👈 자식들 크기만큼만 버튼 크기 잡기
                                  children: [
                                    SvgPicture.asset(
                                      'assets/icons/ico_restore.svg',
                                    ),
                                    const SizedBox(
                                      width: 5,
                                    ), // 👈 여기서 간격을 형님 마음대로 (4~5 추천)
                                    Text(
                                      'restore'.tr(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13, // 텍스트 크기도 버튼에 맞게 살짝 조절
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // 🎯 IntrinsicHeight 없이 바닥에 붙이기 위해 고정 여백 활용
                            const SizedBox(height: 15),

                            // ─── 하단 유의사항 (기기 바닥 쪽 배치) ───
                            _buildFooterNotice(),

                            // 아이폰 홈 바 영역 대응을 위한 여백
                            SizedBox(
                              height: MediaQuery.of(context).padding.bottom,
                            ),
                          ],
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

  // ─── 상단 다크 헤더 위젯 (이미지 스타일 반영 + 타이틀 추가) ───
  Widget _buildBalanceHeader() {
    final topPadding = MediaQuery.of(context).padding.top;
    final bool adDisabled = _adUsedToday >= _adDailyLimit;

    return Container(
      width: double.infinity,
      color: const Color(0xFF474D51),
      // 노치 영역을 고려하여 top 여백을 줍니다.
      padding: EdgeInsets.fromLTRB(27, topPadding + 20, 27, 24),
      child: Column(
        children: [
          // 🏆 타이틀 및 광고 버튼 행
          Stack(
            alignment: Alignment.center, // 자식들을 중앙에 배치
            children: [
              // 1. 타이틀: Stack의 center 정렬을 받아 무조건 정중앙에 위치
              Text(
                'coin_shop'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 19,
                ),
              ),

              // 2. 광고 리워드 버튼: Align을 사용해 오른쪽 끝으로 강제 배치
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(
                    right: 10,
                  ), // 👈 여기에 원하는 만큼 여백 수치를 넣으세요!
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
          // 잔액 표시 영역
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
                      valueColor: const Color(0xFF58B5FF), // 이미지의 블루 톤
                      labelColor: const Color(0xFF76C2FF), // ✅ 무료 라벨 색상 (연블루)
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBalanceTile(
                      label: 'paid_stamp2'.tr(),
                      value: paid.toString().padLeft(4, '0'),
                      valueColor: const Color(0xFFFFB338), // 이미지의 골드 톤
                      labelColor: const Color(0xFFFFC870), // ✅ 유료 라벨 색상 (골드)
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
    required Color labelColor, // ✅ 1. 색상을 받을 파라미터 추가
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
          Text(
            label,
            style: TextStyle(color: labelColor, fontSize: 13), // ✅ 2. 스타일 적용
          ),
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
          final bool isAnnual = p.packageType == PackageType.annual; // 연간 플랜 체크
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
              isAnnual: isAnnual, // 👈 새로 추가된 파라미터
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
    bool isAnnual = false, // 👈 파라미터 추가
  }) {
    List<Color> gradientColors;

    if (isVip) {
      // 👑 VIP: 럭셔리한 다크 골드 그라데이션
      gradientColors = [const Color(0xFFEE7878), const Color(0xFFBC4646)];
    } else if (isAnnual) {
      // 💜 연간: 실속 있는 퍼플 그라데이션
      gradientColors = [const Color(0xFF977FF6), const Color(0xFF644CC4)];
    } else {
      // 💙 월간: 깔끔한 블루 그라데이션
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
                      text: ' ($price $period)', // ✅ 이렇게!
                      style: const TextStyle(
                        color: Color(0xFFFFD700), // ✨ 골드/옐로우 계열 색상
                        fontWeight: FontWeight.w800, // 좀 더 두껍게 강조
                        fontSize: 15, // 크기도 살짝 키우면 더 잘 보여요
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
                Text(
                  p.storeProduct.title.split('(').first.trim(),
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
                color: Color(0xFF2B2B2B).withOpacity(0.9),
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
      return isKo ? 'VIP' : 'VIP';
    } else if (p.packageType == PackageType.annual) {
      return isKo ? '연간 구독' : 'Annual Premium';
    } else {
      return isKo ? '월간 구독' : 'Monthly Premium';
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
