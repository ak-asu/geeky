import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/api_service.dart';
import '../../core/providers/database_provider.dart';
import '../auth/providers.dart';
import '../location/providers.dart';
import '../shorts/providers.dart';
import 'data/note_feed_scorer.dart';
import 'data/notes_repository.dart';
import 'domain/note_entity.dart';
import 'domain/note_feed_state.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
NotesRepository notesRepository(Ref ref) {
  return NotesRepository(
    ref.read(appDatabaseProvider),
    ref.read(apiServiceProvider),
  );
}

/// Watches all notes from Drift as a stream.
@riverpod
Stream<List<NoteEntity>> allNotes(Ref ref) {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  return ref.watch(notesRepositoryProvider).watchAllNotes(userId);
}

/// Feed state — tracks read/skip/recent topics for scoring.
@Riverpod(keepAlive: true)
class NoteFeed extends _$NoteFeed {
  NotesRepository get _repo => ref.read(notesRepositoryProvider);
  String get _userId => ref.read(currentUserProvider)?.id ?? '';

  @override
  Future<NoteFeedState> build() {
    final userId = ref.watch(currentUserProvider)?.id ?? '';
    return _repo.getFeedState(userId);
  }

  Future<void> toggleRead(String noteId) async {
    final current = state.value ?? const NoteFeedState();
    final List<String> updatedIds;
    if (current.readNoteIds.contains(noteId)) {
      updatedIds = current.readNoteIds.where((id) => id != noteId).toList();
    } else {
      updatedIds = [...current.readNoteIds, noteId];
    }

    final updated = current.copyWith(readNoteIds: updatedIds);
    await _repo.saveFeedState(updated, _userId);
    state = AsyncData(updated);
  }

  Future<void> recordSkip(String noteId) async {
    final current = state.value ?? const NoteFeedState();
    final counts = Map<String, int>.from(current.skipCounts);
    counts[noteId] = (counts[noteId] ?? 0) + 1;

    final updated = current.copyWith(skipCounts: counts);
    await _repo.saveFeedState(updated, _userId);
    state = AsyncData(updated);
  }

  Future<void> toggleBookmark(String noteId) async {
    final current = state.value ?? const NoteFeedState();
    final bookmarked = List<String>.from(current.bookmarkedNoteIds);

    if (bookmarked.contains(noteId)) {
      bookmarked.remove(noteId);
    } else {
      bookmarked.add(noteId);
    }

    final updated = current.copyWith(bookmarkedNoteIds: bookmarked);
    await _repo.saveFeedState(updated, _userId);
    state = AsyncData(updated);
  }

  Future<void> addRecentTopic(String topic) async {
    final current = state.value ?? const NoteFeedState();
    final topics = [topic, ...current.recentTopics].take(10).toList();

    final updated = current.copyWith(recentTopics: topics);
    await _repo.saveFeedState(updated, _userId);
    state = AsyncData(updated);
  }
}

/// Ranked notes for the feed — scored and sorted.
///
/// Watches location context so the feed reactively re-ranks when the user's
/// region resolves (or changes). Location is always optional — null means
/// the location factor (factor 9) is simply skipped.
@riverpod
List<NoteEntity> rankedNoteFeed(Ref ref) {
  final notesAsync = ref.watch(allNotesProvider);
  final feedStateAsync = ref.watch(noteFeedProvider);
  final locationAsync = ref.watch(locationContextProvider);

  final notes = notesAsync.value ?? [];
  final feedState = feedStateAsync.value ?? const NoteFeedState();
  final location = locationAsync.value; // null while loading, denied, or off

  return NoteFeedScorer.rank(notes, feedState, locationContext: location);
}

/// Polls the note processing pipeline and refreshes the shorts feed on completion.
///
/// Kept alive so polling continues even if the originating screen is popped.
/// Call [watchUntilComplete] after note creation — it runs in the background,
/// polls every 5 s up to 3 minutes, then fetches fresh shorts into Drift.
@Riverpod(keepAlive: true)
class NoteProcessingWatcher extends _$NoteProcessingWatcher {
  @override
  void build() {}

  Future<void> watchUntilComplete(String noteId, String userId) async {
    const interval = Duration(seconds: 5);
    const timeout = Duration(minutes: 3);
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(interval);
      try {
        final status = await ref
            .read(notesRepositoryProvider)
            .getNoteProcessingStatus(noteId);
        if (status == 'completed' || status == 'failed') {
          if (status == 'completed') {
            await ref.read(shortsRepositoryProvider).getAllShorts(userId);
          }
          return;
        }
      } catch (_) {
        // Network error — continue polling
      }
    }
  }
}
