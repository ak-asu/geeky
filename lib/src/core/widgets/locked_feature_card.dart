import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class LockedFeatureCard extends StatelessWidget {
  const LockedFeatureCard({
    super.key,
    required this.featureName,
    this.description,
    this.icon,
    this.onTap,
  });

  final String featureName;
  final String? description;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: AppSpacing.paddingAll24,
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.lock_rounded,
              size: 40,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
            AppSpacing.gapV12,
            Text(
              featureName,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (description != null) ...[
              AppSpacing.gapV4,
              Text(
                description!,
                textAlign: TextAlign.center,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            AppSpacing.gapV12,
            FilledButton.tonal(onPressed: onTap, child: const Text('Unlock')),
          ],
        ),
      ),
    );
  }
}
