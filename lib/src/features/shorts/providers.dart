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

/// Streams the set of done short IDs for the current user from Drift.
///
/// Kept alive so the stream persists across navigation. The set is populated
/// by [ShortsFeed.toggleDone] and survives API re-syncs because the done flag
/// is absent from [ShortDto.toCompanion] (i.e. never overwritten on upsert).
@Riverpod(keepAlive: true)
Stream<Set<String>> doneShortIds(Ref ref) {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  if (userId.isEmpty) return const Stream.empty();
  return ref.watch(shortsRepositoryProvider).watchDoneShortIds(userId);
}

/// Manages shorts feed done state.
///
/// State is Drift-backed via [doneShortIdsProvider]:
/// - userId-scoped (survives multi-user sign-in/sign-out on the same device)
/// - persists across app restarts
/// - persists across API re-syncs (isDone is absent from the API companion)
/// - feeds FSRS card creation and learning-path planning
///
/// [toggleDone] applies an optimistic in-memory update for instant UI
/// feedback, then writes to Drift. The Drift stream re-emits and the
/// [build] method re-runs, confirming the final state from the DB.
@Riverpod(keepAlive: true)
class ShortsFeed extends _$ShortsFeed {
  @override
  Set<String> build() {
    return ref.watch(doneShortIdsProvider).value ?? {};
  }

  void toggleDone(String shortId) {
    // Optimistic update — instant UI response before the Drift write completes.
    final updated = {...state};
    if (updated.contains(shortId)) {
      updated.remove(shortId);
    } else {
      updated.add(shortId);
    }
    state = updated;

    // Persist to Drift. The stream re-emits and build() re-runs to confirm.
    final userId = ref.read(currentUserProvider)?.id ?? '';
    if (userId.isEmpty) return;
    ref
        .read(shortsRepositoryProvider)
        .markShortDone(userId, shortId, isDone: updated.contains(shortId))
        .ignore();
  }

  bool isDone(String shortId) => state.contains(shortId);
}
