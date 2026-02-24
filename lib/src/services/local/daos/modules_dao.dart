import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/cached_modules.dart';

part 'modules_dao.g.dart';

@DriftAccessor(tables: [CachedModules])
class ModulesDao extends DatabaseAccessor<AppDatabase> with _$ModulesDaoMixin {
  ModulesDao(super.db);

  Future<List<CachedModule>> getAllModules(String userId) =>
      (select(cachedModules)..where((t) => t.userId.equals(userId))).get();

  Stream<List<CachedModule>> watchAllModules(String userId) =>
      (select(cachedModules)..where((t) => t.userId.equals(userId))).watch();

  Future<CachedModule?> getModuleById(String id) =>
      (select(cachedModules)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertModule(CachedModulesCompanion entry) =>
      into(cachedModules).insertOnConflictUpdate(entry);

  Future<void> insertModules(List<CachedModulesCompanion> entries) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(cachedModules, entries);
    });
  }

  Future<void> updateModule(CachedModulesCompanion entry) => (update(
    cachedModules,
  )..where((t) => t.id.equals(entry.id.value))).write(entry);

  Future<void> deleteModule(String id) =>
      (delete(cachedModules)..where((t) => t.id.equals(id))).go();
}
