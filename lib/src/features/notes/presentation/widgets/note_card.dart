import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/markdown_renderer.dart';
import '../../../../core/widgets/side_action_rail.dart';
import '../../domain/note_entity.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onDone,
    required this.onBookmark,
    this.isDone = false,
    this.isBookmarked = false,
    this.onShare,
    this.onExpand,
  });

  final NoteEntity note;
  final VoidCallback onDone;
  final VoidCallback onBookmark;
  final bool isDone;
  final bool isBookmarked;
  final VoidCallback? onShare;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final sideRailKey = GlobalKey<SideActionRailState>();

    return Stack(
      children: [
        // Content area — tapping collapses the side rail
        GestureDetector(
          onTap: () => sideRailKey.currentState?.collapse(),
          child: _buildContent(context),
        ),

        // Side action rail — overlay at bottom-right
        Positioned(
          right: AppSpacing.s8,
          bottom: AppSpacing.s16,
          child: _buildRail(sideRailKey),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final body = note.content ?? note.extractedText ?? '';
    final hasTitle = note.title != null && note.title!.isNotEmpty;
    final noteType = _formatType(note.type);
    final dateLabel = _formatDate(note.createdAt);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Topic tag
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
              noteType,
              style: context.textTheme.labelSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          AppSpacing.gapV8,

          // Title
          if (hasTitle) ...[
            Text(
              note.title!,
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],

          // Date
          Text(
            dateLabel,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.gapV8,

          // Body — markdown content (scrolls with header)
          if (body.isNotEmpty)
            MarkdownRenderer(data: body, shrinkWrap: true)
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s32),
                child: Text(
                  'No content yet',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRail(GlobalKey<SideActionRailState> railKey) {
    return SideActionRail(
      key: railKey,
      primaryActions: [
        RailAction(
          icon: isDone ? Icons.check_circle_rounded : Icons.check_rounded,
          activeIcon: Icons.check_circle_rounded,
          isActive: isDone,
          label: 'Done',
          onTap: onDone,
        ),
        RailAction(
          icon: isBookmarked
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          activeIcon: Icons.bookmark_rounded,
          isActive: isBookmarked,
          label: 'Save',
          onTap: onBookmark,
        ),
      ],
      expandedActions: [
        if (onShare != null)
          RailAction(
            icon: Icons.share_rounded,
            label: 'Share',
            onTap: onShare!,
          ),
        if (onExpand != null)
          RailAction(
            icon: Icons.open_in_full_rounded,
            label: 'Expand',
            onTap: onExpand!,
          ),
      ],
    );
  }

  String _formatType(String type) {
    return switch (type) {
      'text' => 'Text Note',
      'url' => 'Web Link',
      'pdf' => 'PDF',
      'image' => 'Image',
      'audio' => 'Audio',
      'video' => 'Video',
      _ => type[0].toUpperCase() + type.substring(1),
    };
  }

  String _formatDate(DateTime dateTime) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }
}
