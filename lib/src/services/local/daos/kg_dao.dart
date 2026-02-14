import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/cached_concepts.dart';
import '../tables/cached_relationships.dart';

part 'kg_dao.g.dart';

@DriftAccessor(tables: [CachedConcepts, CachedRelationships])
class KgDao extends DatabaseAccessor<AppDatabase> with _$KgDaoMixin {
  KgDao(super.db);

  // --- Concepts ---

  Future<List<CachedConcept>> getAllConcepts() => select(cachedConcepts).get();

  Stream<List<CachedConcept>> watchAllConcepts() =>
      select(cachedConcepts).watch();

  Future<CachedConcept?> getConceptById(String id) =>
      (select(cachedConcepts)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertConcept(CachedConceptsCompanion entry) =>
      into(cachedConcepts).insertOnConflictUpdate(entry);

  Future<void> insertConcepts(List<CachedConceptsCompanion> entries) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(cachedConcepts, entries);
    });
  }

  // --- Relationships ---

  Future<List<CachedRelationship>> getAllRelationships() =>
      select(cachedRelationships).get();

  Stream<List<CachedRelationship>> watchAllRelationships() =>
      select(cachedRelationships).watch();

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
