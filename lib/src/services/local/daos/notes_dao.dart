import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/cached_notes.dart';

part 'notes_dao.g.dart';

@DriftAccessor(tables: [CachedNotes])
class NotesDao extends DatabaseAccessor<AppDatabase> with _$NotesDaoMixin {
  NotesDao(super.db);

  Future<List<CachedNote>> getAllNotes() => select(cachedNotes).get();

  Stream<List<CachedNote>> watchAllNotes() => select(cachedNotes).watch();

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

  Future<int> countNotes() async {
    final count = cachedNotes.id.count();
    final query = selectOnly(cachedNotes)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count)!;
  }
}
