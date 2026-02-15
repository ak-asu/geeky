import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers/database_provider.dart';
import '../shorts/domain/short_entity.dart';
import 'data/bookmarks_repository.dart';
import 'domain/bookmark_entity.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
BookmarksRepository bookmarksRepository(Ref ref) {
  return BookmarksRepository(ref.read(appDatabaseProvider));
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
