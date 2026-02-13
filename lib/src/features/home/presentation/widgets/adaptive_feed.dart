import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/geeky_empty_state.dart';
import '../../../../core/widgets/premium_gate.dart';

/// Switches between Shorts feed (premium) and Notes feed (free) based on subscription.
/// Actual feed screens will be plugged in during Phase 2 & 3.
class AdaptiveFeed extends ConsumerWidget {
  const AdaptiveFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const PremiumGate(
      featureName: 'Shorts Feed',
      fallback: _NoteFeedPlaceholder(),
      child: _ShortsFeedPlaceholder(),
    );
  }
}

class _NoteFeedPlaceholder extends StatelessWidget {
  const _NoteFeedPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const GeekyEmptyState(
      icon: Icons.note_alt_rounded,
      title: 'Your Note Feed',
      subtitle:
          'Notes you add will appear here as swipeable cards. Create your first note to get started!',
      actionLabel: 'Create Note',
    );
  }
}

class _ShortsFeedPlaceholder extends StatelessWidget {
  const _ShortsFeedPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const GeekyEmptyState(
      icon: Icons.auto_awesome_rounded,
      title: 'Shorts Feed',
      subtitle:
          'AI-generated learning articles from your notes will appear here.',
    );
  }
}
