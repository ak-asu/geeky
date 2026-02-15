import '../../../services/local/database.dart';
import '../../shorts/domain/short_entity.dart';
import '../../shorts/data/short_dto.dart';
import '../domain/bookmark_entity.dart';
import 'bookmark_dto.dart';

class BookmarksRepository {
  BookmarksRepository(this._db);

  final AppDatabase _db;

  /// Watches all bookmarks as entities, ordered by most recent first.
  Stream<List<BookmarkEntity>> watchAllBookmarks() {
    return _db.bookmarksDao.watchAllBookmarks().map(
      (rows) => rows.map(BookmarkDto.fromRow).toList(),
    );
  }

  /// Gets all bookmarks as entities.
  Future<List<BookmarkEntity>> getAllBookmarks() async {
    final rows = await _db.bookmarksDao.getAllBookmarks();
    return rows.map(BookmarkDto.fromRow).toList();
  }

  /// Gets the full ShortEntity for each bookmarked short ID.
  Future<List<ShortEntity>> getBookmarkedShorts(List<String> shortIds) async {
    if (shortIds.isEmpty) return [];
    final rows = await _db.shortsDao.getShortsByIds(shortIds);
    return rows.map(ShortDto.fromRow).toList();
  }

  /// Removes a bookmark by short ID.
  Future<void> removeBookmark(String shortId) async {
    await _db.bookmarksDao.removeBookmark(shortId);
  }
}
