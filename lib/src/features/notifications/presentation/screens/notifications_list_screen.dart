import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/geeky_empty_state.dart';
import '../../../../core/widgets/geeky_error_widget.dart';
import '../../../../core/widgets/geeky_shimmer.dart';
import '../../domain/notification_entity.dart';
import '../../providers.dart';

class NotificationsListScreen extends ConsumerWidget {
  const NotificationsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(allNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: context.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: () {
              ref.read(notificationsRepositoryProvider).markAllAsRead();
              ref.invalidate(allNotificationsProvider);
            },
            child: Text(
              'Read all',
              style: context.textTheme.labelMedium?.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.only(top: AppSpacing.s8),
          itemCount: 4,
          itemBuilder: (_, _) => Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s4,
            ),
            child: GeekyShimmer.listItem(),
          ),
        ),
        error: (error, _) => GeekyErrorWidget(
          message: 'Could not load notifications',
          onRetry: () => ref.invalidate(allNotificationsProvider),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const GeekyEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No Notifications',
              subtitle: 'You\'re all caught up!',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationTile(
                    notification: notification,
                    onTap: () {
                      if (!notification.isRead) {
                        ref
                            .read(notificationsRepositoryProvider)
                            .markAsRead(notification.id);
                        ref.invalidate(allNotificationsProvider);
                      }
                    },
                  )
                  .animate()
                  .fadeIn(duration: 300.ms, delay: (50 * index).ms)
                  .slideY(
                    begin: 0.1,
                    end: 0,
                    duration: 300.ms,
                    delay: (50 * index).ms,
                  );
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final NotificationEntity notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
        decoration: BoxDecoration(
          color: notification.isRead
              ? null
              : AppColors.primary.withValues(alpha: 0.04),
          border: Border(
            bottom: BorderSide(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, size: 20, color: _iconColor),
            ),
            AppSpacing.gapH12,

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.titleSmall?.copyWith(
                            fontWeight: notification.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  AppSpacing.gapV4,
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  AppSpacing.gapV4,
                  Text(
                    _formatTime(notification.createdAt),
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _icon => switch (notification.type) {
    'processing' => Icons.auto_awesome_rounded,
    'review' => Icons.quiz_rounded,
    'achievement' => Icons.emoji_events_rounded,
    'store' => Icons.store_rounded,
    'warning' => Icons.warning_rounded,
    _ => Icons.notifications_rounded,
  };

  Color get _iconColor => switch (notification.type) {
    'processing' => AppColors.primary,
    'review' => AppColors.secondary,
    'achievement' => AppColors.warning,
    'store' => AppColors.primaryDark,
    'warning' => AppColors.error,
    _ => AppColors.primary,
  };

  String _formatTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
