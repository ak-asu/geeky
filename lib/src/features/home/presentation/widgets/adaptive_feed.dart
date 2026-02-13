import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/geeky_empty_state.dart';
import '../../../../core/widgets/premium_gate.dart';
import '../../../notes/presentation/screens/note_feed_screen.dart';

/// Switches between Shorts feed (premium) and Notes feed (free) based on subscription.
class AdaptiveFeed extends ConsumerWidget {
  const AdaptiveFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const PremiumGate(
      featureName: 'Shorts Feed',
      fallback: NoteFeedScreen(),
      child: _ShortsFeedPlaceholder(),
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
