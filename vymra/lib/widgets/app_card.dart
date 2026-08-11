import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable card component with consistent styling.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry? margin;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 16,
    this.backgroundColor,
    this.gradient,
    this.border,
    this.boxShadow,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(borderRadius);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? backgroundColor ?? AppColors.surface : null,
        borderRadius: radius,
        border:
            border ??
            Border.all(color: AppColors.textDisabled.withOpacity(0.16)),
        boxShadow:
            boxShadow ??
            <BoxShadow>[
              BoxShadow(
                color: AppColors.secondaryDark.withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: AppColors.primary.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
