import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:travel_memoir/core/constants/app_colors.dart';
import 'package:travel_memoir/services/payment_service.dart';

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
      // ✅ 가로로 꽉 채우기 위한 설정
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8, // 최대 높이 80% 제한
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
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'coin_shop_desc'.tr(),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 35),

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
                  children: _currentOffering!.availablePackages
                      .map((package) => _buildProductItem(package))
                      .toList(),
                ),
              ),
            ),

          const SizedBox(height: 25),
          TextButton(
            onPressed: () async {
              setState(() => _isLoading = true);
              await PaymentService.restorePurchases();
              if (mounted) {
                setState(() => _isLoading = false);
                _loadProducts(); // 상태 새로고침
              }
            },
            child: Text(
              'restore_purchase'.tr(),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
                decoration: TextDecoration.underline,
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
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: AppColors.primary.withOpacity(0.2),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
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
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.description,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Text(
              product.priceString,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
