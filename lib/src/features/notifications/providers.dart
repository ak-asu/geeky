import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/api_service.dart';
import '../../core/providers/database_provider.dart';
import 'data/notifications_repository.dart';
import 'domain/notification_entity.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
NotificationsRepository notificationsRepository(Ref ref) {
  return NotificationsRepository(
    ref.read(appDatabaseProvider),
    ref.read(apiServiceProvider),
  );
}

@riverpod
Stream<List<NotificationEntity>> allNotifications(Ref ref) {
  return ref.watch(notificationsRepositoryProvider).watchAll();
}
