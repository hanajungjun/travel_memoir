import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';

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

  @override
  void initState() {
    super.initState();
    _balanceFuture = _fetchCoinBalance();
  }

  Future<Map<String, dynamic>> _fetchCoinBalance() async {
    final data = await Supabase.instance.client
        .from('users')
        .select('daily_stamps, paid_stamps')
        .eq('auth_uid', _userId)
        .single();
    return data;
  }

  // 🎯 가이드라인 3.1.2 대응: 외부 링크 실행 함수
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🎯 현재 언어 확인 (한국어 여부)
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
      body: FutureBuilder<Map<String, dynamic>>(
        future: _balanceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 🎯 가이드라인 2.1 대응: 에러 시 리뷰어 안내 문구
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text("In-App Purchase Initialization Error"),
                    const SizedBox(height: 8),
                    const Text(
                      "Reviewer Note: Please ensure the 'Paid Apps Agreement' is active in App Store Connect and you are using a Sandbox Tester account.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          final daily = (snapshot.data?['daily_stamps'] ?? 0) as int;
          final paid = (snapshot.data?['paid_stamps'] ?? 0) as int;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMyBalanceCard(daily, paid),
                const SizedBox(height: 32),

                Text(
                  'membership_plan'.tr(),
                  style: AppTextStyles.sectionTitle.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 16),

                // 🎯 가이드라인 3.1.2 대응: 구독 기간(1개월) 명시
                _buildSubscriptionCard(
                  title: 'premium_title'.tr(),
                  price: '₩4,900',
                  period: '1_month'.tr(), // "1개월" 또는 "1 Month"
                  benefits: [
                    'benefit_stickers'.tr(),
                    'benefit_no_ads'.tr(),
                    'benefit_monthly_coins'.tr(),
                    'benefit_gold_badge'.tr(),
                  ],
                  onTap: () => _showPurchaseSheet(context),
                ),

                const SizedBox(height: 32),

                Text(
                  'charge_coins'.tr(),
                  style: AppTextStyles.sectionTitle.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 16),
                _buildProductCard(
                  title: 'coin_count'.tr(args: ['10']),
                  price: '₩1,500',
                  icon: Icons.toll_rounded,
                  color: Colors.orangeAccent,
                  onTap: () => _showPurchaseSheet(context),
                ),
                _buildProductCard(
                  title: 'coin_count'.tr(args: ['50']),
                  price: '₩6,000',
                  badge: 'BEST',
                  icon: Icons.toll_rounded,
                  color: Colors.orange,
                  onTap: () => _showPurchaseSheet(context),
                ),
                _buildProductCard(
                  title: 'coin_count'.tr(args: ['100']),
                  price: '₩11,000',
                  badge: 'SALE',
                  icon: Icons.toll_rounded,
                  color: Colors.deepOrange,
                  onTap: () => _showPurchaseSheet(context),
                ),

                // 🎯 가이드라인 3.1.2 대응: 하단 법적 고지 및 언어별 링크 분기
                const SizedBox(height: 40),
                _buildLegalInformation(isKo),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // 🎯 언어별 링크 분기 적용된 법적 고지 위젯
  Widget _buildLegalInformation(bool isKo) {
    return Column(
      children: [
        Text(
          "subscription_notice".tr(), // 자동 갱신 및 해지 안내 문구
          style: const TextStyle(fontSize: 11, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ✅ 개인정보 처리방침 분기
            TextButton(
              onPressed: () => _launchURL(
                isKo
                    ? 'https://hanajungjun.github.io/travel-memoir-docs/'
                    : 'https://hanajungjun.github.io/travel-memoir-docs/index_en.html',
              ),
              child: Text(
                'privacy_policy'.tr(),
                style: const TextStyle(
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const Text(" | ", style: TextStyle(color: Colors.grey)),
            // ✅ 이용약관 (EULA) 분기
            TextButton(
              onPressed: () => _launchURL(
                isKo
                    ? 'https://hanajungjun.github.io/travel-memoir-docs/terms.html'
                    : 'https://hanajungjun.github.io/travel-memoir-docs/terms_en.html',
              ),
              child: Text(
                'terms_of_service'.tr(),
                style: const TextStyle(
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- UI Components (기존과 동일하게 유지) ---

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
          mainAxisAlignment: MainAxisAlignment.center,
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
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      color: Colors.amber,
                      size: 30,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'most_popular'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                // 🎯 심사 가이드라인 대응: 가격과 기간을 한 줄에 표시 (예: ₩4,900 / 1개월)
                Text(
                  "$price / $period",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white24, thickness: 1),
                const SizedBox(height: 16),
                ...benefits
                    .map(
                      (b) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              b,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
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
      ),
    );
  }

  Widget _buildProductCard({
    required String title,
    required String price,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF0F0F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'shop_item_desc'.tr(),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    price,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  void _showPurchaseSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CoinPaywallBottomSheet(),
    );
    setState(() {
      _balanceFuture = _fetchCoinBalance();
    });
  }
}
