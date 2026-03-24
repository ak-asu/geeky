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

  Future<List<ShortEntity>> getAllShorts(String userId) async {
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
      final rows = await _shortsDao.getAllShorts(userId);
      return rows.map(ShortDto.fromRow).toList();
    }
  }

  Stream<List<ShortEntity>> watchAllShorts(String userId) {
    return _shortsDao
        .watchAllShorts(userId)
        .map((rows) => rows.map(ShortDto.fromRow).toList());
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

  // --- Done state ---

  /// Persists the done flag for a short in Drift.
  /// The flag is absent from [ShortDto.toCompanion], so it is never
  /// overwritten when the API re-syncs the short via [insertOnConflictUpdate].
  Future<void> markShortDone(
    String userId,
    String shortId, {
    required bool isDone,
  }) => _shortsDao.markShortDone(userId, shortId, isDone: isDone);

  /// Streams the set of short IDs the user has marked as done from Drift.
  Stream<Set<String>> watchDoneShortIds(String userId) =>
      _shortsDao.watchDoneShortIds(userId);

  // --- Bookmarks ---

  Future<bool> isBookmarked(String userId, String shortId) {
    return _bookmarksDao.isBookmarked(userId, shortId);
  }

  Stream<List<String>> watchBookmarkedIds(String userId) {
    return _bookmarksDao
        .watchAllBookmarks(userId)
        .map((rows) => rows.map((r) => r.shortId).toList());
  }
}
