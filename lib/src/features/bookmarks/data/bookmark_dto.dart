import 'package:drift/drift.dart';

import '../../../services/local/database.dart';
import '../domain/bookmark_entity.dart';

abstract final class BookmarkDto {
  static BookmarkEntity fromRow(CachedBookmark row) {
    return BookmarkEntity(
      id: row.id,
      shortId: row.shortId,
      userId: row.userId,
      createdAt: row.createdAt,
    );
  }

  static CachedBookmarksCompanion toCompanion(BookmarkEntity entity) {
    return CachedBookmarksCompanion(
      id: Value(entity.id),
      shortId: Value(entity.shortId),
      userId: Value(entity.userId),
      createdAt: Value(entity.createdAt),
    );
  }
}
