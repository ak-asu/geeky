import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class GeekyErrorWidget extends StatelessWidget {
  const GeekyErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.icon,
    this.compact = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon ?? Icons.error_outline_rounded,
            size: 16,
            color: AppColors.error,
          ),
          AppSpacing.gapH8,
          Flexible(
            child: Text(
              message,
              style: context.textTheme.bodySmall?.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      );
    }

    return Center(
      child: Padding(
        padding: AppSpacing.paddingAll24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error.withValues(alpha: 0.7),
            ),
            AppSpacing.gapV16,
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyLarge?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              AppSpacing.gapV16,
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
