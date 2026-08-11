import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_localizations.dart';
import '../providers/purchase_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/paw_coin_badge.dart';
import '../widgets/pet_coin_icon.dart';

/// In-app purchase store screen.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  @override
  void initState() {
    super.initState();
    context.read<PurchaseProvider>().initialize();
  }

  @override
  Widget build(BuildContext context) {
    final purchaseProvider = context.watch<PurchaseProvider>();
    final products = purchaseProvider.localProducts.entries.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Store')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: PawCoinBadge(balance: purchaseProvider.balance),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!purchaseProvider.isStoreAvailable)
              _StoreNoticeCard(
                message: context.tr(
                  'The App Store is not available right now. Test on a signed iPhone build or StoreKit environment.',
                ),
                color: AppColors.error,
              ),
            if (purchaseProvider.error != null)
              _StoreNoticeCard(
                message: purchaseProvider.error!,
                color: AppColors.error,
              ),
            _BalanceCard(balance: purchaseProvider.balance),
            const SizedBox(height: 24),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 220,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return _ProductCard(
                  productId: product.key,
                  price: product.value['price'] as double,
                  priceLabel: product.value['priceLabel'] as String?,
                  coins: product.value['coins'] as int,
                  isPromotional: product.value['isPromotional'] as bool,
                  onPurchase: _purchaseProduct,
                  isPurchasing: purchaseProvider.isPurchasing,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _purchaseProduct(String productId) async {
    final success = await context.read<PurchaseProvider>().purchaseProduct(
      productId,
    );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Purchase successful! Coins added to your balance.'),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

class _BalanceCard extends StatelessWidget {
  final int balance;

  const _BalanceCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const PetCoinIcon(size: 34),
              const SizedBox(width: 12),
              Text(
                '$balance',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('PawCoins'),
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String productId;
  final double price;
  final String? priceLabel;
  final int coins;
  final bool isPromotional;
  final Function(String) onPurchase;
  final bool isPurchasing;

  const _ProductCard({
    required this.productId,
    required this.price,
    this.priceLabel,
    required this.coins,
    required this.isPromotional,
    required this.onPurchase,
    required this.isPurchasing,
  });

  @override
  Widget build(BuildContext context) {
    final displayPrice = priceLabel ?? '\$${price.toStringAsFixed(2)}';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (isPromotional)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                context.tr('BEST VALUE'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
          const SizedBox(height: 8),
          const PetCoinIcon(size: 34),
          const SizedBox(height: 8),
          Text(
            '$coins',
            style: AppTextStyles.title.copyWith(color: AppColors.primary),
          ),
          Text(context.tr('PawCoins'), style: AppTextStyles.caption),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: isPurchasing ? null : () => onPurchase(productId),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: isPurchasing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      displayPrice,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StoreNoticeCard extends StatelessWidget {
  final String message;
  final Color color;

  const _StoreNoticeCard({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        message,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
