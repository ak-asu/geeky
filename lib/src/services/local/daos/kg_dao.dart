import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/cached_concepts.dart';
import '../tables/cached_relationships.dart';

part 'kg_dao.g.dart';

@DriftAccessor(tables: [CachedConcepts, CachedRelationships])
class KgDao extends DatabaseAccessor<AppDatabase> with _$KgDaoMixin {
  KgDao(super.db);

  // ── Concepts ──────────────────────────────────────────────────────────────

  Future<List<CachedConcept>> getAllConcepts(String userId) =>
      (select(cachedConcepts)..where((t) => t.userId.equals(userId))).get();

  Stream<List<CachedConcept>> watchAllConcepts(String userId) =>
      (select(cachedConcepts)..where((t) => t.userId.equals(userId))).watch();

  Future<CachedConcept?> getConceptById(String userId, String id) =>
      (select(cachedConcepts)
            ..where((t) => t.userId.equals(userId))
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<void> insertConcept(CachedConceptsCompanion entry) =>
      into(cachedConcepts).insertOnConflictUpdate(entry);

  Future<void> insertConcepts(List<CachedConceptsCompanion> entries) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(cachedConcepts, entries);
    });
  }

  // ── Relationships ─────────────────────────────────────────────────────────

  Future<List<CachedRelationship>> getAllRelationships(String userId) =>
      (select(
        cachedRelationships,
      )..where((t) => t.userId.equals(userId))).get();

  Stream<List<CachedRelationship>> watchAllRelationships(String userId) =>
      (select(
        cachedRelationships,
      )..where((t) => t.userId.equals(userId))).watch();

  Future<void> insertRelationship(CachedRelationshipsCompanion entry) =>
      into(cachedRelationships).insertOnConflictUpdate(entry);

  Future<void> insertRelationships(
    List<CachedRelationshipsCompanion> entries,
  ) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(cachedRelationships, entries);
    });
  }
}
