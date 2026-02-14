import '../../../services/local/database.dart';
import '../../../services/local/daos/modules_dao.dart';
import '../domain/module_entity.dart';
import 'module_dto.dart';

class ModulesRepository {
  ModulesRepository(this._db);

  final AppDatabase _db;

  ModulesDao get _modulesDao => _db.modulesDao;

  Future<List<ModuleEntity>> getAllModules() async {
    final rows = await _modulesDao.getAllModules();
    return rows.map(ModuleDto.fromRow).toList();
  }

  Stream<List<ModuleEntity>> watchAllModules() {
    return _modulesDao.watchAllModules().map(
      (rows) => rows.map(ModuleDto.fromRow).toList(),
    );
  }

  Future<ModuleEntity?> getModuleById(String id) async {
    final row = await _modulesDao.getModuleById(id);
    return row != null ? ModuleDto.fromRow(row) : null;
  }

  Future<void> saveModule(ModuleEntity module) async {
    await _modulesDao.insertModule(ModuleDto.toCompanion(module));
  }

  Future<void> updateModule(ModuleEntity module) async {
    await _modulesDao.updateModule(ModuleDto.toCompanion(module));
  }

  Future<void> deleteModule(String id) async {
    await _modulesDao.deleteModule(id);
  }
}
