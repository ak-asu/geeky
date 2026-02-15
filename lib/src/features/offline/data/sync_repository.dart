import 'dart:async';

import '../../../services/local/database.dart';

/// Repository managing the offline sync queue.
/// Reads pending interactions from Drift and flushes them
/// when connectivity is restored.
class SyncRepository {
  SyncRepository(this._db);

  final AppDatabase _db;

  /// Stream of unsynced interaction count.
  Stream<int> watchPendingCount() {
    return _db.syncDao.watchPendingCount();
  }

  /// Gets the number of unsynced interactions.
  Future<int> getPendingCount() async {
    final pending = await _db.syncDao.getPendingInteractions();
    return pending.length;
  }

  /// Attempts to flush all pending interactions.
  /// In a real app, this would POST to the backend.
  /// For mock, we simply mark them as synced.
  Future<int> flushQueue() async {
    final pending = await _db.syncDao.getPendingInteractions();
    if (pending.isEmpty) return 0;

    // Mock: mark all as synced (simulates successful upload)
    await _db.syncDao.markAllSynced();
    return pending.length;
  }
}
