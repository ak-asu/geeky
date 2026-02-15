import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/topic_chip.dart';
import '../../../shorts/domain/short_entity.dart';

class BookmarkCard extends StatelessWidget {
  const BookmarkCard({
    super.key,
    required this.short,
    required this.onTap,
    required this.onRemove,
  });

  final ShortEntity short;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s4,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: BorderSide(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: AppSpacing.paddingAll16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Topics
                    if (short.topics.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                        child: Wrap(
                          spacing: AppSpacing.s4,
                          children: short.topics
                              .take(2)
                              .map((t) => TopicChip(label: t))
                              .toList(),
                        ),
                      ),

                    // Title
                    Text(
                      short.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    AppSpacing.gapV4,

                    // Summary
                    if (short.summary.isNotEmpty)
                      Text(
                        short.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),

              // Remove button
              IconButton(
                icon: const Icon(Icons.bookmark_remove_rounded),
                iconSize: 22,
                color: AppColors.primary,
                tooltip: 'Remove bookmark',
                onPressed: onRemove,
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.all(AppSpacing.s8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
