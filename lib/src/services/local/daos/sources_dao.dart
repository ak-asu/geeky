import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/cached_sources.dart';

part 'sources_dao.g.dart';

@DriftAccessor(tables: [CachedSources])
class SourcesDao extends DatabaseAccessor<AppDatabase> with _$SourcesDaoMixin {
  SourcesDao(super.db);

  Future<List<CachedSource>> getAllSources() => (select(
    cachedSources,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

  Stream<List<CachedSource>> watchAllSources() => (select(
    cachedSources,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  Future<CachedSource?> getSourceById(String id) =>
      (select(cachedSources)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertSource(CachedSourcesCompanion entry) =>
      into(cachedSources).insertOnConflictUpdate(entry);

  Future<void> deleteSource(String id) =>
      (delete(cachedSources)..where((t) => t.id.equals(id))).go();

  Future<void> deleteAll() => delete(cachedSources).go();
}
