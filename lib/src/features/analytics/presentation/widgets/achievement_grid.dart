import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/achievement.dart';

class AchievementGrid extends StatelessWidget {
  const AchievementGrid({super.key, required this.achievements});

  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Achievements',
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${achievements.where((a) => a.isUnlocked).length}/${achievements.length}',
              style: context.textTheme.labelMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        AppSpacing.gapV12,
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.s8,
            crossAxisSpacing: AppSpacing.s8,
            childAspectRatio: 1.6,
          ),
          itemCount: achievements.length,
          itemBuilder: (context, index) {
            return _AchievementTile(achievement: achievements[index]);
          },
        ),
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement});

  final Achievement achievement;

  IconData get _icon {
    return switch (achievement.icon) {
      'auto_stories' => Icons.auto_stories_rounded,
      'menu_book' => Icons.menu_book_rounded,
      'local_fire_department' => Icons.local_fire_department_rounded,
      'quiz' => Icons.quiz_rounded,
      'hub' => Icons.hub_rounded,
      'psychology' => Icons.psychology_rounded,
      'emoji_events' => Icons.emoji_events_rounded,
      'scuba_diving' => Icons.scuba_diving_rounded,
      'star' => Icons.star_rounded,
      'share' => Icons.share_rounded,
      _ => Icons.emoji_events_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.isUnlocked;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s8),
      decoration: BoxDecoration(
        color: unlocked
            ? AppColors.primary.withValues(alpha: 0.06)
            : context.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: unlocked
              ? AppColors.primary.withValues(alpha: 0.2)
              : context.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                _icon,
                size: 22,
                color: unlocked
                    ? AppColors.primary
                    : context.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
              ),
              const Spacer(),
              if (unlocked)
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: AppColors.success.withValues(alpha: 0.8),
                ),
            ],
          ),
          AppSpacing.gapV8,
          Text(
            achievement.title,
            style: context.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: unlocked
                  ? context.colorScheme.onSurface
                  : context.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          AppSpacing.gapV4,
          Text(
            achievement.description,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant.withValues(
                alpha: unlocked ? 0.7 : 0.4,
              ),
              fontSize: 11,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
