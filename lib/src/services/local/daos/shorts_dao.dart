import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/cached_shorts.dart';

part 'shorts_dao.g.dart';

@DriftAccessor(tables: [CachedShorts])
class ShortsDao extends DatabaseAccessor<AppDatabase> with _$ShortsDaoMixin {
  ShortsDao(super.db);

  Future<List<CachedShort>> getAllShorts() => select(cachedShorts).get();

  Stream<List<CachedShort>> watchAllShorts() => select(cachedShorts).watch();

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

  Future<void> deleteAll() => delete(cachedShorts).go();
}
