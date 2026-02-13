import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/geeky_empty_state.dart';
import '../../../../core/widgets/geeky_shimmer.dart';
import '../../../../core/widgets/horizontal_card_feed.dart';
import '../../../../routing/route_names.dart';
import '../../domain/note_entity.dart';
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

    return HorizontalCardFeed<NoteEntity>(
      items: notes,
      onPageChanged: (index) {
        if (index < notes.length) {
          final note = notes[index];
          ref.read(noteFeedProvider.notifier).addRecentTopic(note.type);
        }
      },
      cardBuilder: (context, note, index) {
        return NoteCard(
          note: note,
          onDone: () {
            ref.read(noteFeedProvider.notifier).markRead(note.id);
          },
          onBookmark: () {
            // Bookmark toggling wired in Phase 3
          },
          onExpand: () {
            context.pushNamed(RouteNames.noteDetail, extra: note);
          },
        );
      },
    );
  }
}
