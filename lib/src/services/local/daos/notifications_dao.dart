import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/cached_notifications.dart';

part 'notifications_dao.g.dart';

@DriftAccessor(tables: [CachedNotifications])
class NotificationsDao extends DatabaseAccessor<AppDatabase>
    with _$NotificationsDaoMixin {
  NotificationsDao(super.db);

  Future<List<CachedNotification>> getAll() => (select(
    cachedNotifications,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

  Stream<List<CachedNotification>> watchAll() => (select(
    cachedNotifications,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  Future<void> markAsRead(String id) =>
      (update(cachedNotifications)..where((t) => t.id.equals(id))).write(
        const CachedNotificationsCompanion(isRead: Value(true)),
      );

  Future<void> markAllAsRead() => update(
    cachedNotifications,
  ).write(const CachedNotificationsCompanion(isRead: Value(true)));

  Stream<int> watchUnreadCount() {
    final query = select(cachedNotifications)
      ..where((t) => t.isRead.equals(false));
    return query.watch().map((rows) => rows.length);
  }

  Future<void> insertNotification(CachedNotificationsCompanion entry) =>
      into(cachedNotifications).insertOnConflictUpdate(entry);

  Future<void> deleteAll() => delete(cachedNotifications).go();
}
