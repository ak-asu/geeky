import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/database_provider.dart';
import '../../services/local/database.dart';
import 'data/shorts_repository.dart';
import 'domain/short_entity.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
ShortsRepository shortsRepository(Ref ref) {
  return ShortsRepository(ref.read(appDatabaseProvider));
}

/// Watches all shorts from Drift as a stream.
@riverpod
Stream<List<ShortEntity>> allShorts(Ref ref) {
  return ref.watch(shortsRepositoryProvider).watchAllShorts();
}

/// Watches bookmarked short IDs.
@riverpod
Stream<List<String>> bookmarkedShortIds(Ref ref) {
  return ref.watch(shortsRepositoryProvider).watchBookmarkedIds();
}

/// Manages shorts feed state: done set + bookmark toggles.
@Riverpod(keepAlive: true)
class ShortsFeed extends _$ShortsFeed {
  @override
  Set<String> build() => {};

  void markDone(String shortId) {
    state = {...state, shortId};
  }

  bool isDone(String shortId) => state.contains(shortId);
}

/// Manages bookmark state for shorts.
@Riverpod(keepAlive: true)
class ShortsBookmarks extends _$ShortsBookmarks {
  @override
  Set<String> build() {
    _loadBookmarks();
    return {};
  }

  Future<void> _loadBookmarks() async {
    final db = ref.read(appDatabaseProvider);
    final bookmarks = await db.bookmarksDao.getAllBookmarks();
    state = bookmarks.map((b) => b.shortId).toSet();
  }

  Future<void> toggle(String shortId) async {
    final db = ref.read(appDatabaseProvider);
    if (state.contains(shortId)) {
      await db.bookmarksDao.removeBookmark(shortId);
      state = {...state}..remove(shortId);
    } else {
      await db.bookmarksDao.addBookmark(
        CachedBookmarksCompanion(
          id: Value(const Uuid().v4()),
          shortId: Value(shortId),
          userId: const Value('user-001'),
          createdAt: Value(DateTime.now()),
        ),
      );
      state = {...state, shortId};
    }
  }

  bool isBookmarked(String shortId) => state.contains(shortId);
}
