import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/geeky_empty_state.dart';
import '../../../../core/widgets/geeky_shimmer.dart';
import '../../../../core/widgets/horizontal_card_feed.dart';
import '../../../notes/data/interaction_notifier.dart';
import '../../domain/short_entity.dart';
import '../../providers.dart';
import '../widgets/short_card.dart';
import '../widgets/short_source_sheet.dart';

/// Parameters passed via route extra for filtered shorts feed.
class ShortsFeedParams {
  const ShortsFeedParams({
    this.filterShortIds,
    this.initialIndex = 0,
    this.title,
  });

  /// When non-null, only show shorts with these IDs (in this order).
  final List<String>? filterShortIds;

  /// Which short to start on.
  final int initialIndex;

  /// Optional title for the app bar (e.g. module name).
  final String? title;
}

class ShortsFeedScreen extends ConsumerWidget {
  const ShortsFeedScreen({
    super.key,
    this.filterShortIds,
    this.initialIndex = 0,
  });

  /// When non-null, only shorts matching these IDs are shown (preserving order).
  final List<String>? filterShortIds;

  /// Index of the short to start on.
  final int initialIndex;

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
      data: (allShorts) {
        // Apply filter: keep order from filterShortIds
        final shorts = filterShortIds != null
            ? _filterAndOrder(allShorts, filterShortIds!)
            : allShorts;

        if (shorts.isEmpty) {
          return const GeekyEmptyState(
            icon: Icons.auto_awesome_rounded,
            title: 'Shorts Feed',
            subtitle:
                'AI-generated learning articles from your notes will appear here.',
          );
        }

        return _ShortsFeedBody(shorts: shorts, initialIndex: initialIndex);
      },
    );
  }

  List<ShortEntity> _filterAndOrder(
    List<ShortEntity> allShorts,
    List<String> ids,
  ) {
    final map = {for (final s in allShorts) s.id: s};
    return [
      for (final id in ids)
        if (map.containsKey(id)) map[id]!,
    ];
  }
}

class _ShortsFeedBody extends ConsumerWidget {
  const _ShortsFeedBody({required this.shorts, this.initialIndex = 0});

  final List<ShortEntity> shorts;
  final int initialIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doneSet = ref.watch(shortsFeedProvider);
    final bookmarkSet = ref.watch(shortsBookmarksProvider);

    return HorizontalCardFeed<ShortEntity>(
      items: shorts,
      initialPage: initialIndex,
      cardBuilder: (context, short, index) {
        final isDone = doneSet.contains(short.id);
        final isBookmarked = bookmarkSet.contains(short.id);

        return ShortCard(
          short: short,
          isDone: isDone,
          isBookmarked: isBookmarked,
          onDone: () {
            ref.read(shortsFeedProvider.notifier).toggleDone(short.id);
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
          onRelated: () {
            // Placeholder — show related shorts
          },
          onFeedback: () {
            ref
                .read(interactionProvider.notifier)
                .recordFeedback(articleId: short.id, feedbackType: 'general');
          },
          onTts: () {
            // Placeholder — flutter_tts integration later
          },
          onExploreFurther: short.prompts.isNotEmpty
              ? () => _showExploreSheet(context, short)
              : null,
          onSource: () => ShortSourceSheet.show(context, short),
        );
      },
    );
  }

  void _showExploreSheet(BuildContext context, ShortEntity short) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: AppSpacing.paddingAll16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                    ),
                  ),
                ),
                AppSpacing.gapV16,
                Row(
                  children: [
                    const Icon(
                      Icons.explore_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    AppSpacing.gapH8,
                    Text(
                      'Explore Further',
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapV12,
                ...short.prompts.map(
                  (prompt) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    leading: Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 18,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      prompt,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: context.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      // Placeholder — navigate to RAG query with prompt
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
