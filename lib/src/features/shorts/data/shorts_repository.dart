import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_service.dart';
import '../../../services/local/database.dart';
import '../../../services/local/daos/shorts_dao.dart';
import '../../../services/local/daos/bookmarks_dao.dart';
import '../domain/short_entity.dart';
import 'short_dto.dart';

class ShortsRepository {
  ShortsRepository(this._db, this._api);

  final AppDatabase _db;
  final ApiService _api;

  ShortsDao get _shortsDao => _db.shortsDao;
  BookmarksDao get _bookmarksDao => _db.bookmarksDao;

  // --- Shorts CRUD ---

  Future<List<ShortEntity>> getAllShorts() async {
    try {
      final shorts = await _api.getList(
        ApiConstants.shorts,
        (json) => ShortEntity.fromJson(json as Map<String, dynamic>),
      );
      for (final short in shorts) {
        await _shortsDao.insertShort(ShortDto.toCompanion(short));
      }
      return shorts;
    } catch (_) {
      final rows = await _shortsDao.getAllShorts();
      return rows.map(ShortDto.fromRow).toList();
    }
  }

  Stream<List<ShortEntity>> watchAllShorts() {
    return _shortsDao.watchAllShorts().map(
      (rows) => rows.map(ShortDto.fromRow).toList(),
    );
  }

  Future<ShortEntity?> getShortById(String id) async {
    try {
      final short = await _api.get(
        '${ApiConstants.shorts}/$id',
        (json) => ShortEntity.fromJson(json as Map<String, dynamic>),
      );
      await _shortsDao.insertShort(ShortDto.toCompanion(short));
      return short;
    } catch (_) {
      final row = await _shortsDao.getShortById(id);
      return row != null ? ShortDto.fromRow(row) : null;
    }
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
