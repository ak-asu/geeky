import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_service.dart';
import '../../../services/local/database.dart';
import '../../shorts/domain/short_entity.dart';
import '../../shorts/data/short_dto.dart';
import '../domain/bookmark_entity.dart';
import 'bookmark_dto.dart';

class BookmarksRepository {
  BookmarksRepository(this._db, this._api);

  final AppDatabase _db;
  final ApiService _api;

  /// Watches all bookmarks as entities, ordered by most recent first.
  Stream<List<BookmarkEntity>> watchAllBookmarks() {
    return _db.bookmarksDao.watchAllBookmarks().map(
      (rows) => rows.map(BookmarkDto.fromRow).toList(),
    );
  }

  /// Gets all bookmarks as entities.
  Future<List<BookmarkEntity>> getAllBookmarks() async {
    try {
      final bookmarks = await _api.getList(
        ApiConstants.bookmarks,
        (json) => BookmarkEntity.fromJson(json as Map<String, dynamic>),
      );
      return bookmarks;
    } catch (_) {
      final rows = await _db.bookmarksDao.getAllBookmarks();
      return rows.map(BookmarkDto.fromRow).toList();
    }
  }

  /// Gets the full ShortEntity for each bookmarked short ID.
  Future<List<ShortEntity>> getBookmarkedShorts(List<String> shortIds) async {
    if (shortIds.isEmpty) return [];
    final rows = await _db.shortsDao.getShortsByIds(shortIds);
    return rows.map(ShortDto.fromRow).toList();
  }

  /// Creates a bookmark on the backend and locally.
  Future<void> addBookmark(String shortId) async {
    try {
      await _api.post(
        '${ApiConstants.bookmarks}/$shortId',
        null,
        (json) => json,
      );
    } catch (_) {
      // Will be synced later
    }
  }

  /// Removes a bookmark by short ID.
  Future<void> removeBookmark(String shortId) async {
    try {
      await _api.delete('${ApiConstants.bookmarks}/$shortId');
    } catch (_) {
      // Will be synced later
    }
    await _db.bookmarksDao.removeBookmark(shortId);
  }
}
