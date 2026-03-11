import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/cached_notifications.dart';

part 'notifications_dao.g.dart';

@DriftAccessor(tables: [CachedNotifications])
class NotificationsDao extends DatabaseAccessor<AppDatabase>
    with _$NotificationsDaoMixin {
  NotificationsDao(super.db);

  Future<List<CachedNotification>> getAll(String userId) =>
      (select(cachedNotifications)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Stream<List<CachedNotification>> watchAll(String userId) =>
      (select(cachedNotifications)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<void> markAsRead(String userId, String id) =>
      (update(cachedNotifications)
            ..where((t) => t.userId.equals(userId) & t.id.equals(id)))
          .write(const CachedNotificationsCompanion(isRead: Value(true)));

  Future<void> markAllAsRead(String userId) =>
      (update(cachedNotifications)..where((t) => t.userId.equals(userId)))
          .write(const CachedNotificationsCompanion(isRead: Value(true)));

  Stream<int> watchUnreadCount(String userId) {
    final query = select(cachedNotifications)
      ..where((t) => t.userId.equals(userId) & t.isRead.equals(false));
    return query.watch().map((rows) => rows.length);
  }

  Future<void> insertNotification(CachedNotificationsCompanion entry) =>
      into(cachedNotifications).insertOnConflictUpdate(entry);

  Future<void> deleteAll(String userId) =>
      (delete(cachedNotifications)..where((t) => t.userId.equals(userId))).go();
}
