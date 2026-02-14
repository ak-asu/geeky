import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../notes/presentation/screens/note_feed_screen.dart';
import '../../../shorts/presentation/screens/shorts_feed_screen.dart';
import '../../../shorts/providers.dart';

/// Switches between Shorts feed and Notes feed based on content availability.
///
/// If the user has any accessible shorts (pipeline-generated OR store-downloaded),
/// the Shorts feed is shown. Otherwise, falls back to the Notes feed.
/// This is tier-agnostic — the feed adapts to data, not subscription status.
class AdaptiveFeed extends ConsumerWidget {
  const AdaptiveFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortsAsync = ref.watch(allShortsProvider);

    return shortsAsync.when(
      data: (shorts) {
        if (shorts.isNotEmpty) return const ShortsFeedScreen();
        return const NoteFeedScreen();
      },
      loading: () {
        // While loading, check if we have previous data to avoid flicker
        final previousData = shortsAsync.value;
        if (previousData != null && previousData.isNotEmpty) {
          return const ShortsFeedScreen();
        }
        return const NoteFeedScreen();
      },
      error: (_, _) => const NoteFeedScreen(),
    );
  }
}
