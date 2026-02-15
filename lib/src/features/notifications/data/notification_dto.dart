import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../services/local/database.dart';
import '../domain/notification_entity.dart';

abstract final class NotificationDto {
  static NotificationEntity fromRow(CachedNotification row) {
    return NotificationEntity(
      id: row.id,
      title: row.title,
      body: row.body,
      type: row.type,
      isRead: row.isRead,
      createdAt: row.createdAt,
      data: jsonDecode(row.dataJson) as Map<String, dynamic>,
    );
  }

  static CachedNotificationsCompanion toCompanion(NotificationEntity entity) {
    return CachedNotificationsCompanion(
      id: Value(entity.id),
      title: Value(entity.title),
      body: Value(entity.body),
      type: Value(entity.type),
      isRead: Value(entity.isRead),
      createdAt: Value(entity.createdAt),
      dataJson: Value(jsonEncode(entity.data)),
    );
  }
}
