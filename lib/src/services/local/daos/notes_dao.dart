import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/cached_notes.dart';

part 'notes_dao.g.dart';

@DriftAccessor(tables: [CachedNotes])
class NotesDao extends DatabaseAccessor<AppDatabase> with _$NotesDaoMixin {
  NotesDao(super.db);

  Future<List<CachedNote>> getAllNotes(String userId) =>
      (select(cachedNotes)..where((t) => t.userId.equals(userId))).get();

  Stream<List<CachedNote>> watchAllNotes(String userId) =>
      (select(cachedNotes)..where((t) => t.userId.equals(userId))).watch();

  Future<CachedNote?> getNoteById(String id) =>
      (select(cachedNotes)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertNote(CachedNotesCompanion entry) =>
      into(cachedNotes).insertOnConflictUpdate(entry);

  Future<void> insertNotes(List<CachedNotesCompanion> entries) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(cachedNotes, entries);
    });
  }

  Future<void> deleteNote(String id) =>
      (delete(cachedNotes)..where((t) => t.id.equals(id))).go();

  Future<int> countNotes(String userId) async {
    final count = cachedNotes.id.count();
    final query = selectOnly(cachedNotes)
      ..addColumns([count])
      ..where(cachedNotes.userId.equals(userId));
    final result = await query.getSingle();
    return result.read(count)!;
  }
}
