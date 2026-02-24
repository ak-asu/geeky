import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_service.dart';
import '../../../services/local/database.dart';
import '../domain/content_source_entity.dart';
import 'source_dto.dart';

class SourcesRepository {
  SourcesRepository(this._db, this._api);

  final AppDatabase _db;
  final ApiService _api;

  Stream<List<ContentSourceEntity>> watchAllSources(String userId) {
    return _db.sourcesDao
        .watchAllSources(userId)
        .map((rows) => rows.map(SourceDto.fromRow).toList());
  }

  Future<List<ContentSourceEntity>> getAllSources(String userId) async {
    try {
      final sources = await _api.getList(
        ApiConstants.sources,
        (json) => ContentSourceEntity.fromJson(json as Map<String, dynamic>),
      );
      for (final source in sources) {
        await _db.sourcesDao.insertSource(SourceDto.toCompanion(source));
      }
      return sources;
    } catch (_) {
      final rows = await _db.sourcesDao.getAllSources(userId);
      return rows.map(SourceDto.fromRow).toList();
    }
  }

  Future<ContentSourceEntity?> getSourceById(String id) async {
    final row = await _db.sourcesDao.getSourceById(id);
    return row != null ? SourceDto.fromRow(row) : null;
  }

  Future<void> addSource(ContentSourceEntity source) async {
    try {
      await _api.post(ApiConstants.sources, source.toJson(), (json) => json);
    } catch (_) {
      // Will be synced later
    }
    await _db.sourcesDao.insertSource(SourceDto.toCompanion(source));
  }

  Future<void> removeSource(String id) async {
    try {
      await _api.delete('${ApiConstants.sources}/$id');
    } catch (_) {
      // Will be synced later
    }
    await _db.sourcesDao.deleteSource(id);
  }
}
