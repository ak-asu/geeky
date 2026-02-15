import 'dart:async';

import '../domain/notification_entity.dart';

/// Mock repository for notifications.
class NotificationsRepository {
  final _controller = StreamController<List<NotificationEntity>>.broadcast();
  List<NotificationEntity> _notifications = List.from(_mockNotifications);

  Stream<List<NotificationEntity>> watchAll() {
    _controller.add(_notifications);
    return _controller.stream;
  }

  List<NotificationEntity> getAll() => List.unmodifiable(_notifications);

  void markAsRead(String id) {
    _notifications = _notifications.map((n) {
      if (n.id == id) return n.copyWith(isRead: true);
      return n;
    }).toList();
    _controller.add(_notifications);
  }

  void markAllAsRead() {
    _notifications = _notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    _controller.add(_notifications);
  }

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void dispose() {
    _controller.close();
  }

  static final _mockNotifications = [
    NotificationEntity(
      id: 'notif-001',
      title: 'New shorts generated',
      body:
          'Your note "Neural Network Basics" has been processed into 3 new shorts.',
      type: 'processing',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
    NotificationEntity(
      id: 'notif-002',
      title: 'Review reminder',
      body: 'You have 5 flashcards due for review today.',
      type: 'review',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    NotificationEntity(
      id: 'notif-003',
      title: 'Streak milestone!',
      body: 'You\'ve maintained a 7-day learning streak. Keep it up!',
      type: 'achievement',
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    NotificationEntity(
      id: 'notif-004',
      title: 'New module available',
      body:
          '"Learning How to Learn" is now in the Module Store with 4.9 rating.',
      type: 'store',
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    NotificationEntity(
      id: 'notif-005',
      title: 'Source health warning',
      body: 'Your source "Stanford CS229 Notes" may have moved. Check the URL.',
      type: 'warning',
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];
}
