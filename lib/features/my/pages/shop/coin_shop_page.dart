import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/services/payment_service.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';

class CoinShopPage extends StatefulWidget {
  const CoinShopPage({super.key});

  @override
  State<CoinShopPage> createState() => _CoinShopPageState();
}

class _CoinShopPageState extends State<CoinShopPage> {
  List<Package> _subscriptionPackages = [];
  List<Package> _coinPackages = [];
  bool _isProductsLoading = true;

  late Future<Map<String, int>> _balanceFuture;

  @override
  void initState() {
    super.initState();
    _balanceFuture = _fetchCoinBalances();
    _fetchOfferings();
  }

  // ===============================
  // ✅ 구독 기간 라벨 (RevenueCat 안전 버전)
  // ===============================
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

  // ===============================
  // 코인 잔액
  // ===============================
  Future<Map<String, int>> _fetchCoinBalances() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return {'free': 0, 'paid': 0};

    final res = await Supabase.instance.client
        .from('users')
        .select('daily_stamps, paid_stamps')
        .eq('auth_uid', user.id)
        .single();

    return {'free': res['daily_stamps'] ?? 0, 'paid': res['paid_stamps'] ?? 0};
  }

  // ===============================
  // 상품 로드
  // ===============================
  Future<void> _fetchOfferings() async {
    try {
      Offerings? offerings = await PaymentService.getOfferings();
      if (offerings?.current != null) {
        final allPackages = offerings!.current!.availablePackages;

        setState(() {
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
      debugPrint("❌ 상품 로드 실패: $e");
      setState(() => _isProductsLoading = false);
    }
  }

  // ===============================
  // 결제
  // ===============================
  Future<void> _handlePurchase(Package package) async {
    setState(() => _isProductsLoading = true);

    final success = await PaymentService.purchasePackage(package);
    if (success) {
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _balanceFuture = _fetchCoinBalances();
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('upgrade_success_msg'.tr())));
      }
    }

    setState(() => _isProductsLoading = false);
  }

  @override
  Widget build(BuildContext context) {
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
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await PaymentService.restorePurchases();
              setState(() {
                _balanceFuture = _fetchCoinBalances();
              });
            },
            child: Text(
              'restore'.tr(),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
      body: _isProductsLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBalanceCard(),
                  const SizedBox(height: 12),

                  Text(
                    'membership_plan'.tr(),
                    style: AppTextStyles.sectionTitle,
                  ),
                  const SizedBox(height: 12),

                  // ===============================
                  // ✅ 구독 카드 (애플 통과 버전)
                  // ===============================
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

                  const SizedBox(height: 12),

                  Text('charge_coins'.tr(), style: AppTextStyles.sectionTitle),
                  const SizedBox(height: 12),

                  _buildCoinGrid(),
                  const SizedBox(height: 4),
                  _buildFooterNotice(),
                ],
              ),
            ),
    );
  }

  // ===============================
  // UI
  // ===============================
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
                    'free_coins'.tr(),
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.stars, color: Colors.blue, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$free',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'my_coins'.tr(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.stars, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '$paid',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$price $period",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 14,
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: benefits
                    .map(
                      (b) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 10,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            b,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ],
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
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _coinPackages.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (context, index) {
        final p = _coinPackages[index];
        return InkWell(
          onTap: () => _handlePurchase(p),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stars, color: Colors.amber, size: 24),
                const SizedBox(height: 8),
                Text(
                  p.storeProduct.title.split('(').first.trim(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  p.storeProduct.priceString,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
    return Column(
      children: [
        Text(
          'subscription_notice'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {},
              child: Text(
                'privacy_policy'.tr(),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const Text('|', style: TextStyle(color: Colors.grey)),
            TextButton(
              onPressed: () {},
              child: Text(
                'terms_of_service'.tr(),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
