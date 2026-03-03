import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/cached_shorts.dart';

part 'shorts_dao.g.dart';

@DriftAccessor(tables: [CachedShorts])
class ShortsDao extends DatabaseAccessor<AppDatabase> with _$ShortsDaoMixin {
  ShortsDao(super.db);

  Future<List<CachedShort>> getAllShorts(String userId) =>
      (select(cachedShorts)..where((t) => t.userId.equals(userId))).get();

  Stream<List<CachedShort>> watchAllShorts(String userId) =>
      (select(cachedShorts)..where((t) => t.userId.equals(userId))).watch();

  Future<CachedShort?> getShortById(String id) =>
      (select(cachedShorts)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<CachedShort>> getShortsByIds(List<String> ids) =>
      (select(cachedShorts)..where((t) => t.id.isIn(ids))).get();

  Future<void> insertShort(CachedShortsCompanion entry) =>
      into(cachedShorts).insertOnConflictUpdate(entry);

  Future<void> insertShorts(List<CachedShortsCompanion> entries) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(cachedShorts, entries);
    });
  }

  Future<void> deleteShort(String id) =>
      (delete(cachedShorts)..where((t) => t.id.equals(id))).go();

  Future<void> deleteAll(String userId) =>
      (delete(cachedShorts)..where((t) => t.userId.equals(userId))).go();

  /// Persists the done flag for a single short without touching any other column.
  Future<void> markShortDone(
    String userId,
    String shortId, {
    required bool isDone,
  }) =>
      (update(cachedShorts)
            ..where((t) => t.userId.equals(userId))
            ..where((t) => t.id.equals(shortId)))
          .write(CachedShortsCompanion(isDone: Value(isDone)));

  /// Streams the set of short IDs the user has marked as done.
  Stream<Set<String>> watchDoneShortIds(String userId) =>
      (select(cachedShorts)
            ..where((t) => t.userId.equals(userId))
            ..where((t) => t.isDone.equals(true)))
          .watch()
          .map((rows) => {for (final r in rows) r.id});
}
