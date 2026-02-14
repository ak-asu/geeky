import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/geeky_empty_state.dart';
import '../../../../core/widgets/geeky_shimmer.dart';
import '../../../../core/widgets/horizontal_card_feed.dart';
import '../../../notes/data/interaction_notifier.dart';
import '../../domain/short_entity.dart';
import '../../providers.dart';
import '../widgets/short_card.dart';

class ShortsFeedScreen extends ConsumerWidget {
  const ShortsFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortsAsync = ref.watch(allShortsProvider);

    return shortsAsync.when(
      loading: () => GeekyShimmer.feedCard(context),
      error: (error, _) => GeekyEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Could not load Shorts',
        subtitle: error.toString(),
      ),
      data: (shorts) {
        if (shorts.isEmpty) {
          return const GeekyEmptyState(
            icon: Icons.auto_awesome_rounded,
            title: 'Shorts Feed',
            subtitle:
                'AI-generated learning articles from your notes will appear here.',
          );
        }

        return _ShortsFeedBody(shorts: shorts);
      },
    );
  }
}

class _ShortsFeedBody extends ConsumerWidget {
  const _ShortsFeedBody({required this.shorts});

  final List<ShortEntity> shorts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doneSet = ref.watch(shortsFeedProvider);
    final bookmarkSet = ref.watch(shortsBookmarksProvider);

    return HorizontalCardFeed<ShortEntity>(
      items: shorts,
      cardBuilder: (context, short, index) {
        final isDone = doneSet.contains(short.id);
        final isBookmarked = bookmarkSet.contains(short.id);

        return ShortCard(
          short: short,
          isDone: isDone,
          isBookmarked: isBookmarked,
          onDone: () {
            ref.read(shortsFeedProvider.notifier).markDone(short.id);
            ref
                .read(interactionProvider.notifier)
                .recordDone(articleId: short.id);
          },
          onBookmark: () {
            ref.read(shortsBookmarksProvider.notifier).toggle(short.id);
            ref
                .read(interactionProvider.notifier)
                .recordBookmark(articleId: short.id);
          },
          onShare: () {
            // Placeholder — share_plus integration later
          },
          onDiveDeeper: () {
            // Placeholder — navigate to related deeper short
          },
          onGoUp: () {
            // Placeholder — navigate to prerequisite short
          },
          onRelated: () {
            // Placeholder — show related shorts
          },
          onFeedback: () {
            ref
                .read(interactionProvider.notifier)
                .recordFeedback(
                  articleId: short.id,
                  feedbackType: 'general',
                );
          },
          onTts: () {
            // Placeholder — flutter_tts integration later
          },
        );
      },
    );
  }
}
