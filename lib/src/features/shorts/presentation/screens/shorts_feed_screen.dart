import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/providers/shared_preferences_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/geeky_empty_state.dart';
import '../../../../core/widgets/geeky_shimmer.dart';
import '../../../../core/widgets/horizontal_card_feed.dart';
import '../../../../routing/route_names.dart';
import '../../../auth/providers.dart';
import '../../../bookmarks/providers.dart';
import '../../../notes/data/interaction_notifier.dart';
import '../../../quiz/domain/quiz_card_entity.dart';
import '../../../quiz/providers.dart';
import '../../../subscription/providers.dart';
import '../../../tts/tts_controller.dart';
import '../../../tts/tts_state.dart';
import '../../domain/short_entity.dart';
import '../../providers.dart';
import '../widgets/related_shorts_sheet.dart';
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

        return _ShortsFeedBody(
          shorts: shorts,
          allShorts: allShorts,
          initialIndex: initialIndex,
        );
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

class _ShortsFeedBody extends ConsumerStatefulWidget {
  const _ShortsFeedBody({
    required this.shorts,
    required this.allShorts,
    this.initialIndex = 0,
  });

  final List<ShortEntity> shorts;

  /// Full unfiltered list — needed for related-shorts lookups.
  final List<ShortEntity> allShorts;

  final int initialIndex;

  @override
  ConsumerState<_ShortsFeedBody> createState() => _ShortsFeedBodyState();
}

class _ShortsFeedBodyState extends ConsumerState<_ShortsFeedBody> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onPageChanged(int index) {
    // Stop TTS whenever the user swipes to a different short.
    ref.read(ttsControllerProvider.notifier).stop();
    setState(() => _currentIndex = index);
  }

  void _handleTts(ShortEntity short) {
    final isPremium = ref.read(isPremiumProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    final ttsEnabled = prefs.getBool(StorageKeys.ttsEnabled) ?? false;

    if (!isPremium || !ttsEnabled) {
      context.showSnackBar(
        isPremium
            ? 'Enable Text-to-Speech in Settings to use this feature.'
            : 'Text-to-Speech is a Premium feature.',
      );
      return;
    }

    ref.read(ttsControllerProvider.notifier).toggle(short.content);
  }

  void _handleDiveDeeper(BuildContext context, ShortEntity short) {
    if (short.related.isEmpty) {
      context.showSnackBar('No deeper content available for this short.');
      return;
    }
    // Navigate to the first related short in a filtered feed.
    context.pushNamed(
      RouteNames.shortsFeed,
      extra: ShortsFeedParams(filterShortIds: [short.related.first]),
    );
  }

  void _handleRelated(BuildContext context, ShortEntity short) {
    if (short.related.isEmpty) {
      context.showSnackBar('No related shorts found.');
      return;
    }
    RelatedShortsSheet.show(
      context,
      relatedIds: short.related,
      allShorts: widget.allShorts,
    );
  }

  @override
  Widget build(BuildContext context) {
    final doneSet = ref.watch(shortsFeedProvider);
    final bookmarkSet = ref.watch(bookmarkToggleProvider);
    final userId = ref.watch(currentUserProvider)?.id ?? '';
    final ttsState = ref.watch(ttsControllerProvider);

    return HorizontalCardFeed<ShortEntity>(
      items: widget.shorts,
      initialPage: widget.initialIndex,
      onPageChanged: _onPageChanged,
      cardBuilder: (context, short, index) {
        final isDone = doneSet.contains(short.id);
        final isBookmarked = bookmarkSet.contains(short.id);
        // Only mark the current card as speaking (not every card in the list).
        final isSpeaking =
            index == _currentIndex && ttsState == TtsState.speaking;

        return ShortCard(
          short: short,
          isDone: isDone,
          isBookmarked: isBookmarked,
          isSpeaking: isSpeaking,
          onDone: () {
            final wasDone = doneSet.contains(short.id);
            ref.read(shortsFeedProvider.notifier).toggleDone(short.id);
            ref
                .read(interactionProvider.notifier)
                .recordDone(articleId: short.id);

            // Create a quiz card for newly completed shorts (local bridge
            // until the backend pipeline generates cards server-side).
            if (!wasDone) {
              final quizRepo = ref.read(quizRepositoryProvider);
              quizRepo.getCardForArticle(userId, short.id).then((existing) {
                if (existing == null) {
                  quizRepo.saveCard(
                    userId,
                    QuizCardEntity(
                      articleId: short.id,
                      dueDate: DateTime.now(),
                    ),
                  );
                }
              });
            }
          },
          onBookmark: () {
            ref.read(bookmarkToggleProvider.notifier).toggle(short.id);
            ref
                .read(interactionProvider.notifier)
                .recordBookmark(articleId: short.id);
          },
          onShare: () {
            // share_plus integration — wired when share_plus is invoked
          },
          onDiveDeeper: short.related.isNotEmpty
              ? () => _handleDiveDeeper(context, short)
              : null,
          onRelated: short.related.isNotEmpty
              ? () => _handleRelated(context, short)
              : null,
          onFeedback: () {
            ref
                .read(interactionProvider.notifier)
                .recordFeedback(articleId: short.id, feedbackType: 'general');
          },
          onTts: () => _handleTts(short),
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
      builder: (ctx) {
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
                      Navigator.of(ctx).pop();
                      context.pushNamed(RouteNames.ragQuery, extra: prompt);
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
