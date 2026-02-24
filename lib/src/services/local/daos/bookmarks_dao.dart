import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/cached_bookmarks.dart';

part 'bookmarks_dao.g.dart';

@DriftAccessor(tables: [CachedBookmarks])
class BookmarksDao extends DatabaseAccessor<AppDatabase>
    with _$BookmarksDaoMixin {
  BookmarksDao(super.db);

  Future<List<CachedBookmark>> getAllBookmarks(String userId) =>
      (select(cachedBookmarks)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Stream<List<CachedBookmark>> watchAllBookmarks(String userId) =>
      (select(cachedBookmarks)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<bool> isBookmarked(String userId, String shortId) async {
    final result =
        await (select(cachedBookmarks)..where(
              (t) => t.userId.equals(userId) & t.shortId.equals(shortId),
            ))
            .getSingleOrNull();
    return result != null;
  }

  Future<void> addBookmark(CachedBookmarksCompanion entry) =>
      into(cachedBookmarks).insertOnConflictUpdate(entry);

  Future<void> removeBookmark(String userId, String shortId) => (delete(
    cachedBookmarks,
  )..where((t) => t.userId.equals(userId) & t.shortId.equals(shortId))).go();
}
