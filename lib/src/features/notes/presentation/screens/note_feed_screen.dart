import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/geeky_empty_state.dart';
import '../../../../core/widgets/geeky_shimmer.dart';
import '../../../../core/widgets/horizontal_card_feed.dart';
import '../../../../routing/route_names.dart';
import '../../data/interaction_notifier.dart';
import '../../domain/note_entity.dart';
import '../../domain/note_feed_state.dart';
import '../../providers.dart';
import '../widgets/note_card.dart';

class NoteFeedScreen extends ConsumerWidget {
  const NoteFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(rankedNoteFeedProvider);

    if (notes.isEmpty) {
      final allNotesAsync = ref.watch(allNotesProvider);
      return allNotesAsync.when(
        loading: () => GeekyShimmer.feedCard(context),
        error: (_, _) => GeekyEmptyState(
          icon: Icons.note_alt_rounded,
          title: 'Your Note Feed',
          subtitle:
              'Create your first note to see it here as a swipeable card.',
          actionLabel: 'Create Note',
          onAction: () => context.pushNamed(RouteNames.createNote),
        ),
        data: (data) {
          if (data.isEmpty) {
            return GeekyEmptyState(
              icon: Icons.note_alt_rounded,
              title: 'Your Note Feed',
              subtitle:
                  'Create your first note to see it here as a swipeable card.',
              actionLabel: 'Create Note',
              onAction: () => context.pushNamed(RouteNames.createNote),
            );
          }
          return GeekyShimmer.feedCard(context);
        },
      );
    }

    final feedState =
        ref.watch(noteFeedProvider).value ?? const NoteFeedState();

    return HorizontalCardFeed<NoteEntity>(
      items: notes,
      onPageChanged: (index) {
        if (index < notes.length) {
          final note = notes[index];
          ref.read(noteFeedProvider.notifier).addRecentTopic(note.type);
        }
      },
      cardBuilder: (context, note, index) {
        final isDone = feedState.readNoteIds.contains(note.id);
        final isBookmarked = feedState.bookmarkedNoteIds.contains(note.id);

        return NoteCard(
          note: note,
          isDone: isDone,
          isBookmarked: isBookmarked,
          onDone: () {
            ref.read(noteFeedProvider.notifier).markRead(note.id);
            ref
                .read(interactionProvider.notifier)
                .recordDone(articleId: note.id);
          },
          onBookmark: () {
            ref.read(noteFeedProvider.notifier).toggleBookmark(note.id);
            ref
                .read(interactionProvider.notifier)
                .recordBookmark(articleId: note.id);
          },
          onExpand: () {
            context.pushNamed(RouteNames.noteDetail, extra: note);
          },
        );
      },
    );
  }
}
