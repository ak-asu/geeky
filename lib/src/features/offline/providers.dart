import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers/connectivity_provider.dart';
import '../../core/providers/database_provider.dart';
import 'data/sync_repository.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
SyncRepository syncRepository(Ref ref) {
  return SyncRepository(ref.read(appDatabaseProvider));
}

/// Watches the count of unsynced pending interactions.
@riverpod
Stream<int> pendingSyncCount(Ref ref) {
  return ref.watch(syncRepositoryProvider).watchPendingCount();
}

/// Auto-flush: watches connectivity and flushes queue when back online.
/// Returns the number of items flushed in the last sync attempt.
@Riverpod(keepAlive: true)
Future<int> syncOnReconnect(Ref ref) async {
  final isOffline = ref.watch(isOfflineProvider);

  // Only flush when online
  if (isOffline) return 0;

  return ref.read(syncRepositoryProvider).flushQueue();
}
