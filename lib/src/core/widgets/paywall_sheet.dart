import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../extensions/context_extensions.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class PaywallSheet extends StatelessWidget {
  const PaywallSheet({
    super.key,
    this.featureName,
    this.onSubscribe,
    this.onDismiss,
  });

  final String? featureName;
  final VoidCallback? onSubscribe;
  final VoidCallback? onDismiss;

  static Future<void> show(
    BuildContext context, {
    String? featureName,
    VoidCallback? onSubscribe,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          PaywallSheet(featureName: featureName, onSubscribe: onSubscribe),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      padding: AppSpacing.paddingAll24,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            AppSpacing.gapV24,

            // Icon
            Container(
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            AppSpacing.gapV16,

            // Title
            Text(
              'Unlock ${featureName ?? 'Premium'}',
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            AppSpacing.gapV8,

            // Description
            Text(
              'Get access to all premium features including Shorts, Knowledge Graph, Quizzes, and more.',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            AppSpacing.gapV24,

            // Feature list
            ..._features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    AppSpacing.gapH12,
                    Text(f, style: context.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
            AppSpacing.gapV24,

            // CTA Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onSubscribe ?? () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: AppSpacing.paddingV16,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                child: const Text(
                  'Subscribe Now',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ),
            AppSpacing.gapV8,

            // Dismiss
            TextButton(
              onPressed: onDismiss ?? () => Navigator.of(context).pop(),
              child: Text(
                'Maybe Later',
                style: TextStyle(color: context.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _features = [
    PremiumFeatures.shortsFeed,
    PremiumFeatures.knowledgeGraph,
    PremiumFeatures.ragQuery,
    PremiumFeatures.quiz,
    PremiumFeatures.analytics,
    PremiumFeatures.unlimitedSources,
  ];
}
