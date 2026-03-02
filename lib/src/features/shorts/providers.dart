import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/api_service.dart';
import '../../core/providers/database_provider.dart';
import '../auth/providers.dart';
import 'data/shorts_repository.dart';
import 'domain/short_entity.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
ShortsRepository shortsRepository(Ref ref) {
  return ShortsRepository(
    ref.read(appDatabaseProvider),
    ref.read(apiServiceProvider),
  );
}

/// Watches all shorts from Drift as a live stream.
///
/// Kept alive so the stream persists across navigation and mode toggles.
/// Triggers an API fetch on first build to hydrate Drift; the Drift stream
/// reacts to the resulting writes automatically.
@Riverpod(keepAlive: true)
Stream<List<ShortEntity>> allShorts(Ref ref) {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  final repo = ref.watch(shortsRepositoryProvider);
  if (userId.isNotEmpty) {
    repo.getAllShorts(userId).ignore();
  }
  return repo.watchAllShorts(userId);
}

/// Watches bookmarked short IDs.
@riverpod
Stream<List<String>> bookmarkedShortIds(Ref ref) {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  return ref.watch(shortsRepositoryProvider).watchBookmarkedIds(userId);
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
