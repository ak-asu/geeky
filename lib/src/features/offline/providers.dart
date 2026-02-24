import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/api_service.dart';
import '../../core/providers/connectivity_provider.dart';
import '../../core/providers/database_provider.dart';
import '../auth/providers.dart';
import 'data/sync_repository.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
SyncRepository syncRepository(Ref ref) {
  return SyncRepository(
    ref.read(appDatabaseProvider),
    ref.read(apiServiceProvider),
  );
}

/// Watches the count of unsynced pending interactions.
@riverpod
Stream<int> pendingSyncCount(Ref ref) {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  return ref.watch(syncRepositoryProvider).watchPendingCount(userId);
}

/// Auto-flush: watches connectivity and flushes queue when back online.
/// Returns the number of items flushed in the last sync attempt.
@Riverpod(keepAlive: true)
Future<int> syncOnReconnect(Ref ref) async {
  final isOffline = ref.watch(isOfflineProvider);

  // Only flush when online
  if (isOffline) return 0;

  final userId = ref.watch(currentUserProvider)?.id ?? '';
  return ref.read(syncRepositoryProvider).flushQueue(userId);
}

/// Full sync: pull all user data from backend to populate Drift cache.
/// Called once on login or app launch when online.
@riverpod
Future<void> fullSync(Ref ref) async {
  final isOffline = ref.watch(isOfflineProvider);
  if (isOffline) return;

  // Trigger a fresh pull for key data — repositories handle
  // caching internally via their network-first pattern.
  // Invalidate dependent providers to trigger refetch.
  ref.invalidate(syncOnReconnectProvider);
}
