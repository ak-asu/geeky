import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/topic_progress.dart';

class TopicProgressList extends StatelessWidget {
  const TopicProgressList({super.key, required this.topics});

  final List<TopicProgress> topics;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Topic Progress',
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        AppSpacing.gapV12,
        ...topics.take(8).map((tp) => _TopicProgressTile(progress: tp)),
      ],
    );
  }
}

class _TopicProgressTile extends StatelessWidget {
  const _TopicProgressTile({required this.progress});

  final TopicProgress progress;

  Color get _masteryColor {
    if (progress.mastery >= 0.8) return AppColors.success;
    if (progress.mastery >= 0.5) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              progress.topic,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppSpacing.gapH12,
          Expanded(
            flex: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.s4),
              child: LinearProgressIndicator(
                value: progress.mastery,
                minHeight: 8,
                backgroundColor: context.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(_masteryColor),
              ),
            ),
          ),
          AppSpacing.gapH12,
          SizedBox(
            width: 40,
            child: Text(
              '${(progress.mastery * 100).toInt()}%',
              style: context.textTheme.labelSmall?.copyWith(
                color: _masteryColor,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
