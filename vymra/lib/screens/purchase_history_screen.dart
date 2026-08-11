import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_localizations.dart';
import '../providers/purchase_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/loading_widget.dart';
import '../widgets/pet_coin_icon.dart';

/// Purchase history screen showing all transactions and balance changes.
class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PurchaseProvider>().loadRecords();
    });
  }

  @override
  Widget build(BuildContext context) {
    final purchaseProvider = context.watch<PurchaseProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Purchase History'))),
      body: purchaseProvider.isLoading
          ? Center(
              child: LoadingWidget(message: context.tr('Loading records...')),
            )
          : purchaseProvider.records.isEmpty
          ? EmptyStateWidget(
              title: context.tr('No Purchase Records'),
              message: context.tr(
                'Your purchase and transaction history will appear here.',
              ),
            )
          : RefreshIndicator(
              onRefresh: () => purchaseProvider.loadRecords(),
              color: AppColors.primary,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: purchaseProvider.records.length,
                itemBuilder: (context, index) {
                  final record = purchaseProvider.records[index];
                  final isBalanceRecord = record.productId == 'balance';
                  final isPurchase = record.price > 0;

                  if (isBalanceRecord) return const SizedBox.shrink();

                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isPurchase
                                ? AppColors.success.withValues(alpha: 0.1)
                                : AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(child: PetCoinIcon(size: 24)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPurchase
                                    ? context.tr(
                                        'Purchased {coins} PawCoins',
                                        params: <String, String>{
                                          'coins': '${record.coinsAwarded}',
                                        },
                                      )
                                    : context.tr(
                                        'Used {coins} PawCoins',
                                        params: <String, String>{
                                          'coins':
                                              '${record.coinsAwarded.abs()}',
                                        },
                                      ),
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(record.purchasedAt),
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              isPurchase
                                  ? '+${record.coinsAwarded}'
                                  : '${record.coinsAwarded}',
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isPurchase
                                    ? AppColors.success
                                    : AppColors.primary,
                              ),
                            ),
                            if (isPurchase)
                              Text(
                                '\$${record.price.toStringAsFixed(2)}',
                                style: AppTextStyles.caption,
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
