import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_service.dart';
import '../../../services/local/database.dart';
import '../../../services/local/daos/modules_dao.dart';
import '../domain/module_entity.dart';
import 'module_dto.dart';

class ModulesRepository {
  ModulesRepository(this._db, this._api);

  final AppDatabase _db;
  final ApiService _api;

  ModulesDao get _modulesDao => _db.modulesDao;

  Future<List<ModuleEntity>> getAllModules(String userId) async {
    try {
      final modules = await _api.getList(
        ApiConstants.modules,
        (json) => ModuleEntity.fromJson(json as Map<String, dynamic>),
      );
      for (final module in modules) {
        await _modulesDao.insertModule(ModuleDto.toCompanion(module));
      }
      return modules;
    } catch (_) {
      final rows = await _modulesDao.getAllModules(userId);
      return rows.map(ModuleDto.fromRow).toList();
    }
  }

  Stream<List<ModuleEntity>> watchAllModules(String userId) {
    return _modulesDao
        .watchAllModules(userId)
        .map((rows) => rows.map(ModuleDto.fromRow).toList());
  }

  Future<ModuleEntity?> getModuleById(String id) async {
    try {
      final module = await _api.get(
        '${ApiConstants.modules}/$id',
        (json) => ModuleEntity.fromJson(json as Map<String, dynamic>),
      );
      await _modulesDao.insertModule(ModuleDto.toCompanion(module));
      return module;
    } catch (_) {
      final row = await _modulesDao.getModuleById(id);
      return row != null ? ModuleDto.fromRow(row) : null;
    }
  }

  Future<void> saveModule(ModuleEntity module) async {
    try {
      await _api.post(ApiConstants.modules, module.toJson(), (json) => json);
    } catch (_) {
      // Will be synced later
    }
    await _modulesDao.insertModule(ModuleDto.toCompanion(module));
  }

  Future<void> updateModule(ModuleEntity module) async {
    try {
      await _api.patch(
        '${ApiConstants.modules}/${module.id}',
        module.toJson(),
        (json) => json,
      );
    } catch (_) {
      // Will be synced later
    }
    await _modulesDao.updateModule(ModuleDto.toCompanion(module));
  }

  Future<void> deleteModule(String id) async {
    try {
      await _api.delete('${ApiConstants.modules}/$id');
    } catch (_) {
      // Will be synced later
    }
    await _modulesDao.deleteModule(id);
  }
}
