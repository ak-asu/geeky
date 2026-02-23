import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../providers.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier = ref.watch(subscriptionProvider);
    final isPremium = tier == SubscriptionTier.premium;

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: ListView(
        padding: AppSpacing.paddingAll16,
        children: [
          // Current plan badge
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s8,
              ),
              decoration: BoxDecoration(
                color: isPremium
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : context.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(
                isPremium ? 'Premium Active' : 'Free Plan',
                style: context.textTheme.labelLarge?.copyWith(
                  color: isPremium
                      ? AppColors.primary
                      : context.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          AppSpacing.gapV32,

          // Plan comparison
          _PlanCard(
            title: 'Free',
            price: '\$0',
            period: 'forever',
            features: const [
              'Notes (up to ${FreeTierLimits.maxNotes})',
              'Note Feed',
              'Basic Search',
              'Up to ${FreeTierLimits.maxSources} Sources',
              'Up to ${FreeTierLimits.maxStoreModules} Store Downloads',
            ],
            isActive: !isPremium,
            onSelect: null,
          ),
          AppSpacing.gapV12,

          _PlanCard(
            title: 'Premium',
            price: '\$9.99',
            period: '/month',
            features: const [
              'Everything in Free',
              PremiumFeatures.shortsFeed,
              PremiumFeatures.knowledgeGraph,
              PremiumFeatures.ragQuery,
              PremiumFeatures.quiz,
              PremiumFeatures.analytics,
              'AI Processing Pipeline',
              PremiumFeatures.unlimitedSources,
              PremiumFeatures.unlimitedStore,
              'Text-to-Speech',
            ],
            isActive: isPremium,
            isPremium: true,
            onSelect: !isPremium
                ? () => context.showSnackBar('Premium upgrade coming soon!')
                : null,
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.features,
    required this.isActive,
    this.isPremium = false,
    this.onSelect,
  });

  final String title;
  final String price;
  final String period;
  final List<String> features;
  final bool isActive;
  final bool isPremium;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: BorderSide(
          color: isActive
              ? AppColors.primary
              : context.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: AppSpacing.paddingAll16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                if (isPremium)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.s8),
                    child: Icon(
                      Icons.workspace_premium_rounded,
                      color: isActive
                          ? AppColors.primary
                          : context.colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                  ),
                Text(
                  title,
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                    ),
                    child: Text(
                      'Active',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            AppSpacing.gapV8,

            // Price
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: context.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    period,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.gapV16,

            // Features
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: isActive
                          ? AppColors.primary
                          : context.colorScheme.onSurfaceVariant,
                    ),
                    AppSpacing.gapH8,
                    Expanded(
                      child: Text(f, style: context.textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
            ),
            AppSpacing.gapV8,

            // Action button
            if (onSelect != null)
              SizedBox(
                width: double.infinity,
                child: isPremium
                    ? FilledButton(
                        onPressed: onSelect,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                          ),
                        ),
                        child: const Text('Upgrade to Premium'),
                      )
                    : OutlinedButton(
                        onPressed: onSelect,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                          ),
                        ),
                        child: const Text('Switch to Free'),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
