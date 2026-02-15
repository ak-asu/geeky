import '../../../services/local/database.dart';
import '../domain/store_module_entity.dart';
import 'store_module_dto.dart';

class StoreRepository {
  StoreRepository(this._db);

  final AppDatabase _db;

  Stream<List<StoreModuleEntity>> watchAllModules() {
    return _db.storeDao.watchAllModules().map(
      (rows) => rows.map(StoreModuleDto.fromRow).toList(),
    );
  }

  Future<List<StoreModuleEntity>> getAllModules() async {
    final rows = await _db.storeDao.getAllModules();
    return rows.map(StoreModuleDto.fromRow).toList();
  }

  Future<StoreModuleEntity?> getModuleById(String id) async {
    final row = await _db.storeDao.getModuleById(id);
    return row != null ? StoreModuleDto.fromRow(row) : null;
  }

  Future<void> toggleDownload(String id) async {
    await _db.storeDao.toggleDownload(id);
  }

  Future<int> get downloadedCount => _db.storeDao.getDownloadedCount();
}
