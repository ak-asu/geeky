import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers/database_provider.dart';
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

/// Manages shorts feed state: done set.
@Riverpod(keepAlive: true)
class ShortsFeed extends _$ShortsFeed {
  @override
  Set<String> build() => {};

  void toggleDone(String shortId) {
    final updated = {...state};
    if (updated.contains(shortId)) {
      updated.remove(shortId);
    } else {
      updated.add(shortId);
    }
    state = updated;
  }

  bool isDone(String shortId) => state.contains(shortId);
}
