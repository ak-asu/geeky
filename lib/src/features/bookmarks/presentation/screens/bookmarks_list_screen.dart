import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/geeky_empty_state.dart';
import '../../../../core/widgets/geeky_error_widget.dart';
import '../../../../core/widgets/geeky_shimmer.dart';
import '../../../../routing/route_names.dart';
import '../../../shorts/domain/short_entity.dart';
import '../../../shorts/providers.dart';
import '../../../shorts/presentation/screens/shorts_feed_screen.dart';
import '../../providers.dart';
import '../widgets/bookmark_card.dart';

class BookmarksListScreen extends ConsumerWidget {
  const BookmarksListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarkedShortsAsync = ref.watch(bookmarkedShortsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bookmarks',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: context.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: bookmarkedShortsAsync.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.only(top: AppSpacing.s8),
          itemCount: 5,
          itemBuilder: (_, _) => Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s4,
            ),
            child: GeekyShimmer.listItem(),
          ),
        ),
        error: (error, _) => GeekyErrorWidget(
          message: 'Could not load bookmarks',
          onRetry: () => ref.invalidate(bookmarkedShortsProvider),
        ),
        data: (shorts) {
          if (shorts.isEmpty) {
            return const GeekyEmptyState(
              icon: Icons.bookmark_border_rounded,
              title: 'No Bookmarks Yet',
              subtitle:
                  'Bookmark shorts from the feed to save them here for later.',
            );
          }
          return _BookmarksList(shorts: shorts);
        },
      ),
    );
  }
}

class _BookmarksList extends ConsumerWidget {
  const _BookmarksList({required this.shorts});

  final List<ShortEntity> shorts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      itemCount: shorts.length,
      itemBuilder: (context, index) {
        final short = shorts[index];
        return BookmarkCard(
              short: short,
              onTap: () => context.pushNamed(
                RouteNames.shortsFeed,
                extra: ShortsFeedParams(
                  filterShortIds: [short.id],
                  title: short.title,
                ),
              ),
              onRemove: () async {
                await ref
                    .read(shortsBookmarksProvider.notifier)
                    .toggle(short.id);
                ref.invalidate(bookmarkedShortsProvider);
                if (context.mounted) {
                  context.showSnackBar('Bookmark removed');
                }
              },
            )
            .animate()
            .fadeIn(duration: 300.ms, delay: (50 * index).ms)
            .slideY(
              begin: 0.1,
              end: 0,
              duration: 300.ms,
              delay: (50 * index).ms,
            );
      },
    );
  }
}
