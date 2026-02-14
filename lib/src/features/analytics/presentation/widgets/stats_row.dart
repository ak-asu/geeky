import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/analytics_repository.dart';

class StatsRow extends StatelessWidget {
  const StatsRow({super.key, required this.stats});

  final AnalyticsStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.auto_stories_rounded,
            value: '${stats.totalShortsCompleted}',
            label: 'Completed',
            color: AppColors.primary,
          ),
        ),
        AppSpacing.gapH12,
        Expanded(
          child: _StatTile(
            icon: Icons.topic_rounded,
            value: '${stats.totalTopicsCovered}',
            label: 'Topics',
            color: AppColors.secondary,
          ),
        ),
        AppSpacing.gapH12,
        Expanded(
          child: _StatTile(
            icon: Icons.timer_rounded,
            value: '${stats.totalTimeMinutes}m',
            label: 'Time',
            color: AppColors.warning,
          ),
        ),
        AppSpacing.gapH12,
        Expanded(
          child: _StatTile(
            icon: Icons.speed_rounded,
            value: stats.learningVelocity.toStringAsFixed(1),
            label: '/day',
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.s12,
        horizontal: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          AppSpacing.gapV4,
          Text(
            value,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
