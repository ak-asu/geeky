import '../../../services/local/database.dart';
import '../domain/notification_entity.dart';
import 'notification_dto.dart';

class NotificationsRepository {
  NotificationsRepository(this._db);

  final AppDatabase _db;

  Stream<List<NotificationEntity>> watchAll() {
    return _db.notificationsDao.watchAll().map(
      (rows) => rows.map(NotificationDto.fromRow).toList(),
    );
  }

  Future<List<NotificationEntity>> getAll() async {
    final rows = await _db.notificationsDao.getAll();
    return rows.map(NotificationDto.fromRow).toList();
  }

  Future<void> markAsRead(String id) async {
    await _db.notificationsDao.markAsRead(id);
  }

  Future<void> markAllAsRead() async {
    await _db.notificationsDao.markAllAsRead();
  }

  Stream<int> watchUnreadCount() {
    return _db.notificationsDao.watchUnreadCount();
  }
}
