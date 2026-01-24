import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/shared/styles/text_styles.dart';
import 'package:travel_memoir/core/widgets/coin_paywall_bottom_sheet.dart';

class CoinShopPage extends StatefulWidget {
  const CoinShopPage({super.key});

  @override
  State<CoinShopPage> createState() => _CoinShopPageState();
}

class _CoinShopPageState extends State<CoinShopPage> {
  late Future<Map<String, dynamic>> _balanceFuture;
  final String _userId = Supabase.instance.client.auth.currentUser!.id;

  // 💎 RevenueCat 상품 리스트
  List<Package> _subscriptionPackages = [];
  List<Package> _coinPackages = [];
  List<Package> _mapPackages = [];
  bool _isProductsLoading = true;

  @override
  void initState() {
    super.initState();
    _balanceFuture = _fetchCoinBalance();
    _fetchOfferings(); // 상품 목록 가져오기
  }

  // 🎯 RevenueCat 상품 로드 및 분류
  Future<void> _fetchOfferings() async {
    try {
      debugPrint("🚀 [RevenueCat] 상품 로드 시작...");
      Offerings offerings = await Purchases.getOfferings();

      if (offerings.current != null) {
        final allPackages = offerings.current!.availablePackages;

        setState(() {
          // 🎯 수정된 로직: ID에 특정 단어가 포함되어 있는지 확인 (더 유연함)
          _subscriptionPackages = allPackages.where((p) {
            final id = p.storeProduct.identifier;
            return id.contains('monthly') ||
                id.contains('annual') ||
                id.startsWith('sub_');
          }).toList();

          _coinPackages = allPackages.where((p) {
            final id = p.storeProduct.identifier;
            return id.contains('coin') || id.startsWith('coin_');
          }).toList();

          _mapPackages = allPackages.where((p) {
            final id = p.storeProduct.identifier;
            return id.contains('map') || id.startsWith('map_');
          }).toList();

          _isProductsLoading = false;
        });

        debugPrint(
          "📦 분류 결과: 구독(${_subscriptionPackages.length}), 코인(${_coinPackages.length}), 지도(${_mapPackages.length})",
        );
      }
    } catch (e) {
      debugPrint("❌ 에러: $e");
      setState(() => _isProductsLoading = false);
    }
  }

  Future<Map<String, dynamic>> _fetchCoinBalance() async {
    final data = await Supabase.instance.client
        .from('users')
        .select('daily_stamps, paid_stamps')
        .eq('auth_uid', _userId)
        .single();
    return data;
  }

  Future<void> _handlePurchase(Package package) async {
    try {
      debugPrint("💳 결제 시도: ${package.storeProduct.identifier}");
      await Purchases.purchasePackage(package);
      setState(() {
        _balanceFuture = _fetchCoinBalance(); // 결제 후 잔액 갱신
      });
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) !=
          PurchasesErrorCode.purchaseCancelledError) {
        debugPrint("❌ 결제 실패: ${e.message}");
      }
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isKo = context.locale.languageCode == 'ko';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text('coin_shop'.tr(), style: AppTextStyles.sectionTitle),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isProductsLoading
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<Map<String, dynamic>>(
              future: _balanceFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError)
                  return const Center(child: Text("Error loading balance"));

                final daily = (snapshot.data?['daily_stamps'] ?? 0) as int;
                final paid = (snapshot.data?['paid_stamps'] ?? 0) as int;

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMyBalanceCard(daily, paid),
                      const SizedBox(height: 32),

                      if (_subscriptionPackages.isNotEmpty) ...[
                        Text(
                          'membership_plan'.tr(),
                          style: AppTextStyles.sectionTitle.copyWith(
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._subscriptionPackages.map(
                          (p) => _buildSubscriptionCard(
                            title: p.storeProduct.title,
                            price: p.storeProduct.priceString,
                            period: '1_month'.tr(),
                            benefits: [
                              'benefit_ai_picker'.tr(),
                              'benefit_monthly_coins'.tr(),
                            ],
                            onTap: () => _handlePurchase(p),
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      if (_coinPackages.isNotEmpty) ...[
                        Text(
                          'charge_coins'.tr(),
                          style: AppTextStyles.sectionTitle.copyWith(
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._coinPackages.map(
                          (p) => _buildProductCard(
                            title: p.storeProduct.title,
                            price: p.storeProduct.priceString,
                            icon: Icons.toll_rounded,
                            color: Colors.orange,
                            onTap: () => _handlePurchase(p),
                          ),
                        ),
                      ],

                      const SizedBox(height: 40),
                      _buildLegalInformation(isKo),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // --- 🛠️ 형님이 찾으시던 UI Helper Methods ---

  Widget _buildMyBalanceCard(int daily, int paid) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppColors.travelingBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'my_coins'.tr(),
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBalanceItem('free'.tr(), daily, const Color(0xFF3498DB)),
              Container(width: 1, height: 40, color: Colors.grey[100]),
              _buildBalanceItem('stored'.tr(), paid, const Color(0xFFF39C12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.toll_rounded, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ],
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
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "$price / $period",
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ...benefits.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        b,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard({
    required String title,
    required String price,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(
          price,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent,
          ),
        ),
      ),
    );
  }

  Widget _buildLegalInformation(bool isKo) {
    return Column(
      children: [
        Text(
          "subscription_notice".tr(),
          style: const TextStyle(fontSize: 11, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => _launchURL(
                isKo
                    ? 'https://hanajungjun.github.io/travel-memoir-docs/'
                    : 'https://hanajungjun.github.io/travel-memoir-docs/index_en.html',
              ),
              child: Text(
                'privacy_policy'.tr(),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const Text("|"),
            TextButton(
              onPressed: () => _launchURL(
                isKo
                    ? 'https://hanajungjun.github.io/travel-memoir-docs/terms.html'
                    : 'https://hanajungjun.github.io/travel-memoir-docs/terms_en.html',
              ),
              child: Text(
                'terms_of_service'.tr(),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
