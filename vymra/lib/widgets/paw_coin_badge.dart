import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pet_coin_icon.dart';

/// Paw coin balance badge displayed in header areas.
class PawCoinBadge extends StatelessWidget {
  final int balance;
  final VoidCallback? onTap;

  const PawCoinBadge({super.key, required this.balance, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PetCoinIcon(size: 18),
            const SizedBox(width: 4),
            Text(
              '$balance',
              style: AppTextStyles.body.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
