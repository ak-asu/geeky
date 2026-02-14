import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/premium_gate.dart';
import '../../../notes/presentation/screens/note_feed_screen.dart';
import '../../../shorts/presentation/screens/shorts_feed_screen.dart';

/// Switches between Shorts feed (premium) and Notes feed (free) based on subscription.
class AdaptiveFeed extends ConsumerWidget {
  const AdaptiveFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const PremiumGate(
      featureName: 'Shorts Feed',
      fallback: NoteFeedScreen(),
      child: ShortsFeedScreen(),
    );
  }
}
