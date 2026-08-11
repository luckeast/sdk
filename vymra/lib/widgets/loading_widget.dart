import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Loading indicator with custom paw print animation.
class LoadingWidget extends StatelessWidget {
  final double size;
  final String? message;
  final Color color;

  const LoadingWidget({
    super.key,
    this.size = 48,
    this.message,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
