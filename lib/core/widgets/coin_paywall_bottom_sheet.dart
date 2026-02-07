import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/services/payment_service.dart';
import 'package:travel_memoir/features/my/pages/shop/coin_shop_page.dart';

class CoinPaywallBottomSheet extends StatefulWidget {
  const CoinPaywallBottomSheet({super.key});

  @override
  State<CoinPaywallBottomSheet> createState() => _CoinPaywallBottomSheetState();
}

class _CoinPaywallBottomSheetState extends State<CoinPaywallBottomSheet> {
  Offering? _currentOffering;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final offering = await PaymentService.getCurrentOffering();
    if (mounted) {
      setState(() {
        _currentOffering = offering;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75, // 높이 적정 수준 조절
      ),
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 40),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 상단 핸들 바
          Container(
            width: 45,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'coin_shop_title'.tr(),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'coin_shop_desc'.tr(),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 15,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(),
            )
          else if (_currentOffering == null ||
              _currentOffering!.availablePackages.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'no_products'.tr(),
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: () {
                    // 1. 코인 상품만 필터링 (List<Package>)
                    final coinPackages = _currentOffering!.availablePackages
                        .where(
                          (package) => package.storeProduct.identifier
                              .toLowerCase()
                              .contains('coin'),
                        )
                        .toList();

                    // 2. 가격 낮은 순으로 정렬
                    coinPackages.sort(
                      (a, b) =>
                          a.storeProduct.price.compareTo(b.storeProduct.price),
                    );

                    // 3. 위젯 리스트로 변환 (List<Widget>)
                    return coinPackages
                        .map((package) => _buildProductItem(package))
                        .toList();
                  }(),
                ),
              ),
            ),

          const SizedBox(height: 20),

          // 상점으로 이동하는 버튼 (광고 대신 배치)
          TextButton(
            onPressed: () {
              // 1. 먼저 바텀 시트를 닫습니다.
              Navigator.pop(context);

              // 2. 코인 상점 페이지로 이동합니다.
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CoinShopPage()),
              );
            },

            child: Text(
              'go_to_shop_btn'.tr(), // "전체 상점 보기"
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(Package package) {
    final product = package.storeProduct;
    return GestureDetector(
      onTap: () async {
        setState(() => _isLoading = true);
        bool success = await PaymentService.purchasePackage(package);
        if (mounted) {
          setState(() => _isLoading = false);
          if (success) {
            Navigator.pop(context, true); // 성공 시 true 반환
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[200]!, width: 1.5),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.description,
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              product.priceString,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
