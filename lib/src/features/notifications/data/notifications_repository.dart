import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_service.dart';
import '../../../services/local/database.dart';
import '../domain/notification_entity.dart';
import 'notification_dto.dart';

class NotificationsRepository {
  NotificationsRepository(this._db, this._api);

  final AppDatabase _db;
  final ApiService _api;

  Stream<List<NotificationEntity>> watchAll(String userId) {
    return _db.notificationsDao
        .watchAll(userId)
        .map((rows) => rows.map(NotificationDto.fromRow).toList());
  }

  Future<List<NotificationEntity>> getAll(String userId) async {
    try {
      final notifications = await _api.getList(
        ApiConstants.notifications,
        (json) => NotificationEntity.fromJson(json as Map<String, dynamic>),
      );
      for (final n in notifications) {
        await _db.notificationsDao.insertNotification(
          NotificationDto.toCompanion(n),
        );
      }
      return notifications;
    } catch (_) {
      final rows = await _db.notificationsDao.getAll(userId);
      return rows.map(NotificationDto.fromRow).toList();
    }
  }

  Future<void> markAsRead(String userId, String id) async {
    try {
      await _api.postVoid('${ApiConstants.notifications}/$id/read', null);
    } catch (_) {
      // Will be synced later
    }
    await _db.notificationsDao.markAsRead(userId, id);
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      await _api.postVoid('${ApiConstants.notifications}/read-all', null);
    } catch (_) {
      // Will be synced later
    }
    await _db.notificationsDao.markAllAsRead(userId);
  }

  Stream<int> watchUnreadCount(String userId) {
    return _db.notificationsDao.watchUnreadCount(userId);
  }
}
