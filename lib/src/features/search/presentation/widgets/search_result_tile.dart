import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/topic_chip.dart';
import '../../../shorts/domain/short_entity.dart';

class SearchResultTile extends StatelessWidget {
  const SearchResultTile({super.key, required this.short, required this.onTap});

  final ShortEntity short;
  final VoidCallback onTap;

  String get _difficultyLabel {
    if (short.difficulty <= 0.35) return 'Beginner';
    if (short.difficulty <= 0.65) return 'Intermediate';
    return 'Advanced';
  }

  Color get _difficultyColor {
    if (short.difficulty <= 0.35) return AppColors.success;
    if (short.difficulty <= 0.65) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Leading icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: const Icon(
                Icons.article_rounded,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            AppSpacing.gapH12,

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    short.title,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (short.summary.isNotEmpty) ...[
                    AppSpacing.gapV4,
                    Text(
                      short.summary,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  AppSpacing.gapV8,
                  Row(
                    children: [
                      if (short.topics.isNotEmpty)
                        TopicChip(label: short.topics.first),
                      if (short.topics.isNotEmpty) AppSpacing.gapH8,
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _difficultyColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusFull,
                          ),
                        ),
                        child: Text(
                          _difficultyLabel,
                          style: context.textTheme.labelSmall?.copyWith(
                            color: _difficultyColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Trailing arrow
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: context.colorScheme.onSurfaceVariant.withValues(
                alpha: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
