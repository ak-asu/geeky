import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'data/notifications_repository.dart';
import 'domain/notification_entity.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
NotificationsRepository notificationsRepository(Ref ref) {
  final repo = NotificationsRepository();
  ref.onDispose(repo.dispose);
  return repo;
}

@riverpod
Stream<List<NotificationEntity>> allNotifications(Ref ref) {
  return ref.watch(notificationsRepositoryProvider).watchAll();
}
