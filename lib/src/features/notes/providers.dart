import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers/database_provider.dart';
import 'data/note_feed_scorer.dart';
import 'data/notes_repository.dart';
import 'domain/note_entity.dart';
import 'domain/note_feed_state.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
NotesRepository notesRepository(Ref ref) {
  return NotesRepository(ref.read(appDatabaseProvider));
}

/// Watches all notes from Drift as a stream.
@riverpod
Stream<List<NoteEntity>> allNotes(Ref ref) {
  return ref.watch(notesRepositoryProvider).watchAllNotes();
}

/// Feed state — tracks read/skip/recent topics for scoring.
@Riverpod(keepAlive: true)
class NoteFeed extends _$NoteFeed {
  NotesRepository get _repo => ref.read(notesRepositoryProvider);

  @override
  Future<NoteFeedState> build() => _repo.getFeedState();

  Future<void> markRead(String noteId) async {
    final current = state.value ?? const NoteFeedState();
    if (current.readNoteIds.contains(noteId)) return;

    final updated = current.copyWith(
      readNoteIds: [...current.readNoteIds, noteId],
    );
    await _repo.saveFeedState(updated);
    state = AsyncData(updated);
  }

  Future<void> recordSkip(String noteId) async {
    final current = state.value ?? const NoteFeedState();
    final counts = Map<String, int>.from(current.skipCounts);
    counts[noteId] = (counts[noteId] ?? 0) + 1;

    final updated = current.copyWith(skipCounts: counts);
    await _repo.saveFeedState(updated);
    state = AsyncData(updated);
  }

  Future<void> addRecentTopic(String topic) async {
    final current = state.value ?? const NoteFeedState();
    final topics = [topic, ...current.recentTopics].take(10).toList();

    final updated = current.copyWith(recentTopics: topics);
    await _repo.saveFeedState(updated);
    state = AsyncData(updated);
  }
}

/// Ranked notes for the feed — scored and sorted.
@riverpod
List<NoteEntity> rankedNoteFeed(Ref ref) {
  final notesAsync = ref.watch(allNotesProvider);
  final feedStateAsync = ref.watch(noteFeedProvider);

  final notes = notesAsync.value ?? [];
  final feedState = feedStateAsync.value ?? const NoteFeedState();

  return NoteFeedScorer.rank(notes, feedState);
}
