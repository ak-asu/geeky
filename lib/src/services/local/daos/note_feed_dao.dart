import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/note_feed_state_table.dart';

part 'note_feed_dao.g.dart';

@DriftAccessor(tables: [NoteFeedStateEntries])
class NoteFeedDao extends DatabaseAccessor<AppDatabase>
    with _$NoteFeedDaoMixin {
  NoteFeedDao(super.db);

  Future<NoteFeedStateEntry?> getFeedState(String userId) => (select(
    noteFeedStateEntries,
  )..where((t) => t.userId.equals(userId))).getSingleOrNull();

  Future<void> saveFeedState(NoteFeedStateEntriesCompanion entry) =>
      into(noteFeedStateEntries).insertOnConflictUpdate(entry);
}
