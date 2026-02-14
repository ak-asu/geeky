import '../../../services/local/database.dart';
import '../../../services/local/daos/shorts_dao.dart';
import '../../../services/local/daos/bookmarks_dao.dart';
import '../domain/short_entity.dart';
import 'short_dto.dart';

class ShortsRepository {
  ShortsRepository(this._db);

  final AppDatabase _db;

  ShortsDao get _shortsDao => _db.shortsDao;
  BookmarksDao get _bookmarksDao => _db.bookmarksDao;

  // --- Shorts CRUD ---

  Future<List<ShortEntity>> getAllShorts() async {
    final rows = await _shortsDao.getAllShorts();
    return rows.map(ShortDto.fromRow).toList();
  }

  Stream<List<ShortEntity>> watchAllShorts() {
    return _shortsDao.watchAllShorts().map(
      (rows) => rows.map(ShortDto.fromRow).toList(),
    );
  }

  Future<ShortEntity?> getShortById(String id) async {
    final row = await _shortsDao.getShortById(id);
    return row != null ? ShortDto.fromRow(row) : null;
  }

  Future<List<ShortEntity>> getShortsByIds(List<String> ids) async {
    final rows = await _shortsDao.getShortsByIds(ids);
    return rows.map(ShortDto.fromRow).toList();
  }

  Future<void> saveShort(ShortEntity short) async {
    await _shortsDao.insertShort(ShortDto.toCompanion(short));
  }

  Future<void> deleteShort(String id) async {
    await _shortsDao.deleteShort(id);
  }

  // --- Bookmarks ---

  Future<bool> isBookmarked(String shortId) {
    return _bookmarksDao.isBookmarked(shortId);
  }

  Stream<List<String>> watchBookmarkedIds() {
    return _bookmarksDao.watchAllBookmarks().map(
      (rows) => rows.map((r) => r.shortId).toList(),
    );
  }
}
