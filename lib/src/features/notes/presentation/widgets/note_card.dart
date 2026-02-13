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
    this.isBookmarked = false,
    this.onShare,
    this.onExpand,
  });

  final NoteEntity note;
  final VoidCallback onDone;
  final VoidCallback onBookmark;
  final bool isBookmarked;
  final VoidCallback? onShare;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Content area — scrollable vertically
        _buildContent(context),

        // Side action rail — right edge, vertically centered
        Positioned(
          right: AppSpacing.s8,
          bottom: 0,
          top: 0,
          child: Align(alignment: Alignment.centerRight, child: _buildRail()),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final body = note.content ?? note.extractedText ?? '';
    final hasTitle = note.title != null && note.title!.isNotEmpty;
    final noteType = _formatType(note.type);

    return Padding(
      // Leave space on right for the rail
      padding: const EdgeInsets.only(
        left: AppSpacing.s16,
        right: 64,
        top: AppSpacing.s16,
        bottom: AppSpacing.s16,
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
          AppSpacing.gapV12,

          // Title
          if (hasTitle) ...[
            Text(
              note.title!,
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            AppSpacing.gapV12,
          ],

          // Body — scrollable markdown
          Expanded(
            child: body.isNotEmpty
                ? MarkdownRenderer(data: body)
                : Center(
                    child: Text(
                      'No content yet',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
          ),

          // Footer metadata
          AppSpacing.gapV8,
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final wordLabel = note.wordCount > 0 ? '${note.wordCount} words' : '';
    final timeAgo = _formatTimeAgo(note.createdAt);

    return Row(
      children: [
        if (wordLabel.isNotEmpty) ...[
          Text(
            wordLabel,
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
        ],
        Text(
          timeAgo,
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        if (note.processed) ...[
          const Spacer(),
          Icon(
            Icons.check_circle_rounded,
            size: 14,
            color: AppColors.success.withValues(alpha: 0.7),
          ),
          AppSpacing.gapH4,
          Text(
            'Processed',
            style: context.textTheme.labelSmall?.copyWith(
              color: AppColors.success.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRail() {
    return SideActionRail(
      primaryActions: [
        RailAction(icon: Icons.check_rounded, label: 'Done', onTap: onDone),
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

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
