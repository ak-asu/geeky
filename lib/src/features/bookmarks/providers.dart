import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_service.dart';
import '../../core/providers/database_provider.dart';
import '../../services/local/database.dart';
import '../auth/providers.dart';
import '../shorts/domain/short_entity.dart';
import 'data/bookmarks_repository.dart';
import 'domain/bookmark_entity.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
BookmarksRepository bookmarksRepository(Ref ref) {
  return BookmarksRepository(
    ref.read(appDatabaseProvider),
    ref.read(apiServiceProvider),
  );
}

/// Watches all bookmarks as a stream.
@riverpod
Stream<List<BookmarkEntity>> allBookmarks(Ref ref) {
  return ref.watch(bookmarksRepositoryProvider).watchAllBookmarks();
}

/// Resolves bookmarked short IDs to full ShortEntity list.
@riverpod
Future<List<ShortEntity>> bookmarkedShorts(Ref ref) async {
  final bookmarks = await ref.watch(allBookmarksProvider.future);
  final shortIds = bookmarks.map((b) => b.shortId).toList();
  return ref.read(bookmarksRepositoryProvider).getBookmarkedShorts(shortIds);
}

/// Single source of truth for bookmark toggle state.
/// Used by both shorts feed and bookmarks list screens.
@Riverpod(keepAlive: true)
class BookmarkToggle extends _$BookmarkToggle {
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
    final repo = ref.read(bookmarksRepositoryProvider);

    if (state.contains(shortId)) {
      await repo.removeBookmark(shortId);
      state = {...state}..remove(shortId);
    } else {
      final userId = ref.read(currentUserProvider)?.id ?? 'anonymous';
      await db.bookmarksDao.addBookmark(
        CachedBookmarksCompanion(
          id: Value(const Uuid().v4()),
          shortId: Value(shortId),
          userId: Value(userId),
          createdAt: Value(DateTime.now()),
        ),
      );
      await repo.addBookmark(shortId);
      state = {...state, shortId};
    }
  }

  bool isBookmarked(String shortId) => state.contains(shortId);
}
