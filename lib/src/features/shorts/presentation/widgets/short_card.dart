import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/datetime_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/markdown_renderer.dart';
import '../../../../core/widgets/side_action_rail.dart';
import '../../domain/short_entity.dart';
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
    this.onRelated,
    this.onFeedback,
    this.onTts,
    this.onExploreFurther,
    this.onSource,
    this.onConceptTap,
  });

  final ShortEntity short;
  final bool isDone;
  final bool isBookmarked;
  final VoidCallback onDone;
  final VoidCallback onBookmark;
  final VoidCallback? onShare;
  final VoidCallback? onDiveDeeper;
  final VoidCallback? onRelated;
  final VoidCallback? onFeedback;
  final VoidCallback? onTts;
  final VoidCallback? onExploreFurther;
  final VoidCallback? onSource;
  final ValueChanged<String>? onConceptTap;

  @override
  Widget build(BuildContext context) {
    final sideRailKey = GlobalKey<SideActionRailState>();

    return Stack(
      children: [
        // Content area — tapping it collapses the side rail
        GestureDetector(
          onTap: () => sideRailKey.currentState?.collapse(),
          child: _buildContent(context),
        ),

        // Side action rail — overlay at bottom-right
        Positioned(
          right: AppSpacing.s8,
          bottom: AppSpacing.s16,
          child: ShortActionRail(
            sideRailKey: sideRailKey,
            isDone: isDone,
            isBookmarked: isBookmarked,
            onDone: onDone,
            onBookmark: onBookmark,
            onShare: onShare,
            onDiveDeeper: onDiveDeeper,
            onRelated: onRelated,
            onFeedback: onFeedback,
            onTts: onTts,
            onExploreFurther: onExploreFurther,
            onSource: onSource,
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final primaryTopic = short.topics.isNotEmpty ? short.topics.first : null;
    final dateLabel = short.createdAt.formatDate;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Topic tag
          if (primaryTopic != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s8,
                vertical: AppSpacing.s4,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(
                primaryTopic,
                style: context.textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            AppSpacing.gapV8,
          ],

          // Title
          Text(
            short.title,
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),

          // Date
          Text(
            dateLabel,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.gapV8,

          // Body — markdown content (scrolls with header)
          MarkdownRenderer(data: short.content, shrinkWrap: true),

          // Navigation chips (KG concepts)
          if (short.topics.length > 1) ...[
            AppSpacing.gapV16,
            NavigationOptions(
              conceptNames: short.topics,
              onConceptTap: onConceptTap,
            ),
          ],
        ],
      ),
    );
  }
}
