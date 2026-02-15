import '../../../services/local/database.dart';
import '../domain/content_source_entity.dart';
import 'source_dto.dart';

class SourcesRepository {
  SourcesRepository(this._db);

  final AppDatabase _db;

  Stream<List<ContentSourceEntity>> watchAllSources() {
    return _db.sourcesDao.watchAllSources().map(
      (rows) => rows.map(SourceDto.fromRow).toList(),
    );
  }

  Future<List<ContentSourceEntity>> getAllSources() async {
    final rows = await _db.sourcesDao.getAllSources();
    return rows.map(SourceDto.fromRow).toList();
  }

  Future<ContentSourceEntity?> getSourceById(String id) async {
    final row = await _db.sourcesDao.getSourceById(id);
    return row != null ? SourceDto.fromRow(row) : null;
  }

  Future<void> addSource(ContentSourceEntity source) async {
    await _db.sourcesDao.insertSource(SourceDto.toCompanion(source));
  }

  Future<void> removeSource(String id) async {
    await _db.sourcesDao.deleteSource(id);
  }
}
