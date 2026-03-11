import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/pending_interactions.dart';

part 'sync_dao.g.dart';

@DriftAccessor(tables: [PendingInteractions])
class SyncDao extends DatabaseAccessor<AppDatabase> with _$SyncDaoMixin {
  SyncDao(super.db);

  Future<List<PendingInteraction>> getPendingInteractions(String userId) =>
      (select(pendingInteractions)
            ..where((t) => t.userId.equals(userId) & t.synced.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
          .get();

  Stream<int> watchPendingCount(String userId) {
    final count = pendingInteractions.id.count(
      filter:
          pendingInteractions.userId.equals(userId) &
          pendingInteractions.synced.equals(false),
    );
    final query = selectOnly(pendingInteractions)..addColumns([count]);
    return query.watchSingle().map((row) => row.read(count)!);
  }

  Future<void> insertInteraction(PendingInteractionsCompanion entry) =>
      into(pendingInteractions).insert(entry);

  Future<void> markSynced(int id) =>
      (update(pendingInteractions)..where((t) => t.id.equals(id))).write(
        const PendingInteractionsCompanion(synced: Value(true)),
      );

  Future<void> markAllSynced(String userId) =>
      (update(pendingInteractions)
            ..where((t) => t.userId.equals(userId) & t.synced.equals(false)))
          .write(const PendingInteractionsCompanion(synced: Value(true)));

  Future<List<PendingInteraction>> getInteractionsForArticle(
    String userId,
    String articleId,
  ) =>
      (select(pendingInteractions)
            ..where(
              (t) => t.userId.equals(userId) & t.articleId.equals(articleId),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
          .get();
}
