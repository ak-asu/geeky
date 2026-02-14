import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/markdown_renderer.dart';
import '../../domain/short_entity.dart';
import 'exploration_prompts_list.dart';
import 'navigation_options.dart';
import 'short_action_rail.dart';

class ShortCard extends StatelessWidget {
  const ShortCard({
    super.key,
    required this.short,
    required this.isDone,
    required this.isBookmarked,
    required this.onDone,
    required this.onBookmark,
    this.onShare,
    this.onDiveDeeper,
    this.onGoUp,
    this.onRelated,
    this.onFeedback,
    this.onTts,
    this.onPromptTap,
    this.onConceptTap,
  });

  final ShortEntity short;
  final bool isDone;
  final bool isBookmarked;
  final VoidCallback onDone;
  final VoidCallback onBookmark;
  final VoidCallback? onShare;
  final VoidCallback? onDiveDeeper;
  final VoidCallback? onGoUp;
  final VoidCallback? onRelated;
  final VoidCallback? onFeedback;
  final VoidCallback? onTts;
  final ValueChanged<String>? onPromptTap;
  final ValueChanged<String>? onConceptTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Content area
        _buildContent(context),

        // Side action rail — overlay at bottom-right
        Positioned(
          right: AppSpacing.s8,
          bottom: AppSpacing.s16,
          child: ShortActionRail(
            isDone: isDone,
            isBookmarked: isBookmarked,
            onDone: onDone,
            onBookmark: onBookmark,
            onShare: onShare,
            onDiveDeeper: onDiveDeeper,
            onGoUp: onGoUp,
            onRelated: onRelated,
            onFeedback: onFeedback,
            onTts: onTts,
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final primaryTopic = short.topics.isNotEmpty ? short.topics.first : null;
    final difficultyLabel = _formatDifficulty(short.difficulty);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Topic tag + difficulty
          Row(
            children: [
              if (primaryTopic != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s8,
                    vertical: AppSpacing.s4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text(
                    primaryTopic,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              AppSpacing.gapH8,
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8,
                  vertical: AppSpacing.s4,
                ),
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  difficultyLabel,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.gapV12,

          // Title
          Text(
            short.title,
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          AppSpacing.gapV12,

          // Body — scrollable markdown
          Expanded(
            child: MarkdownRenderer(data: short.content),
          ),

          // Navigation chips (KG concepts)
          if (short.topics.length > 1) ...[
            AppSpacing.gapV8,
            NavigationOptions(
              conceptNames: short.topics,
              onConceptTap: onConceptTap,
            ),
          ],

          // Exploration prompts
          if (short.prompts.isNotEmpty) ...[
            AppSpacing.gapV4,
            ExplorationPromptsList(
              prompts: short.prompts,
              onPromptTap: onPromptTap,
            ),
          ],

          // Footer
          AppSpacing.gapV8,
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final levelLabel = 'Level ${short.level}';
    final timeAgo = _formatTimeAgo(short.createdAt);

    return Row(
      children: [
        Text(
          levelLabel,
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
          child: Text(
            '\u00B7',
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          timeAgo,
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        if (isDone) ...[
          const Spacer(),
          Icon(
            Icons.check_circle_rounded,
            size: 14,
            color: AppColors.success.withValues(alpha: 0.7),
          ),
          AppSpacing.gapH4,
          Text(
            'Done',
            style: context.textTheme.labelSmall?.copyWith(
              color: AppColors.success.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }

  String _formatDifficulty(double difficulty) {
    if (difficulty <= 0.33) return 'Beginner';
    if (difficulty <= 0.66) return 'Intermediate';
    return 'Advanced';
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
