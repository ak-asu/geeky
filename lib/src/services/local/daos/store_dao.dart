import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/cached_store_modules.dart';

part 'store_dao.g.dart';

@DriftAccessor(tables: [CachedStoreModules])
class StoreDao extends DatabaseAccessor<AppDatabase> with _$StoreDaoMixin {
  StoreDao(super.db);

  Future<List<CachedStoreModule>> getAllModules() => (select(
    cachedStoreModules,
  )..orderBy([(t) => OrderingTerm.desc(t.rating)])).get();

  Stream<List<CachedStoreModule>> watchAllModules() => (select(
    cachedStoreModules,
  )..orderBy([(t) => OrderingTerm.desc(t.rating)])).watch();

  Future<CachedStoreModule?> getModuleById(String id) => (select(
    cachedStoreModules,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertModule(CachedStoreModulesCompanion entry) =>
      into(cachedStoreModules).insertOnConflictUpdate(entry);

  Future<void> updateModule(CachedStoreModulesCompanion entry) => (update(
    cachedStoreModules,
  )..where((t) => t.id.equals(entry.id.value))).write(entry);

  Future<void> toggleDownload(String id) async {
    final module = await getModuleById(id);
    if (module == null) return;

    final nowDownloaded = !module.isDownloaded;
    final newDownloads = nowDownloaded
        ? module.downloads + 1
        : module.downloads - 1;

    await (update(cachedStoreModules)..where((t) => t.id.equals(id))).write(
      CachedStoreModulesCompanion(
        isDownloaded: Value(nowDownloaded),
        downloads: Value(newDownloads),
      ),
    );
  }

  Future<int> getDownloadedCount() async {
    final modules = await (select(
      cachedStoreModules,
    )..where((t) => t.isDownloaded.equals(true))).get();
    return modules.length;
  }

  Future<void> deleteAll() => delete(cachedStoreModules).go();
}
