import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/subscription/providers.dart';
import 'locked_feature_card.dart';

/// Gates content behind premium subscription.
/// Shows [child] if premium, otherwise shows [fallback] or a locked card.
class PremiumGate extends ConsumerWidget {
  const PremiumGate({
    super.key,
    required this.child,
    this.fallback,
    this.featureName,
  });

  /// Widget shown when user has premium
  final Widget child;

  /// Widget shown when user is free tier (defaults to locked card)
  final Widget? fallback;

  /// Name of the feature being gated (for display purposes)
  final String? featureName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);

    if (isPremium) return child;

    return fallback ??
        LockedFeatureCard(
          featureName: featureName ?? 'Premium Feature',
          description: 'Upgrade to unlock this feature.',
        );
  }
}
