import 'dart:async';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_service.dart';
import '../../../services/local/database.dart';

/// Repository managing the offline sync queue.
/// Reads pending interactions from Drift and flushes them
/// to the backend when connectivity is restored.
class SyncRepository {
  SyncRepository(this._db, this._api);

  final AppDatabase _db;
  final ApiService _api;

  /// Stream of unsynced interaction count.
  Stream<int> watchPendingCount() {
    return _db.syncDao.watchPendingCount();
  }

  /// Gets the number of unsynced interactions.
  Future<int> getPendingCount() async {
    final pending = await _db.syncDao.getPendingInteractions();
    return pending.length;
  }

  /// Attempts to flush all pending interactions to the backend.
  /// Posts in batch to /api/v1/sync/interactions.
  /// Marks each interaction as synced on success.
  /// Stops on first failure to preserve ordering.
  Future<int> flushQueue() async {
    final pending = await _db.syncDao.getPendingInteractions();
    if (pending.isEmpty) return 0;

    // Build batch payload matching InteractionBatchRequest
    final interactions = pending
        .map(
          (row) => {
            'articleId': row.articleId,
            'type': row.type,
            'timestamp': row.timestamp.toIso8601String(),
            'timeSpent': row.timeSpent,
            'scrollDepth': row.scrollDepth,
            if (row.feedbackType != null) 'feedbackType': row.feedbackType,
            if (row.navigationDirection != null)
              'navigationDirection': row.navigationDirection,
            if (row.fromArticleId != null) 'fromArticleId': row.fromArticleId,
          },
        )
        .toList();

    try {
      await _api.post('${ApiConstants.sync}/interactions', {
        'interactions': interactions,
      }, (json) => json);
      // All synced successfully — mark in Drift
      await _db.syncDao.markAllSynced();
      return pending.length;
    } catch (_) {
      // Batch failed — try one-by-one for partial progress
      int synced = 0;
      for (final row in pending) {
        try {
          await _api.post('${ApiConstants.sync}/interactions', {
            'interactions': [
              {
                'articleId': row.articleId,
                'type': row.type,
                'timestamp': row.timestamp.toIso8601String(),
                'timeSpent': row.timeSpent,
                'scrollDepth': row.scrollDepth,
                if (row.feedbackType != null) 'feedbackType': row.feedbackType,
                if (row.navigationDirection != null)
                  'navigationDirection': row.navigationDirection,
                if (row.fromArticleId != null)
                  'fromArticleId': row.fromArticleId,
              },
            ],
          }, (json) => json);
          await _db.syncDao.markSynced(row.id);
          synced++;
        } catch (_) {
          break; // Stop on first failure, retry next reconnect
        }
      }
      return synced;
    }
  }
}
