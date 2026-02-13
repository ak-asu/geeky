import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/datetime_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/markdown_renderer.dart';
import '../../domain/note_entity.dart';

class NoteDetailScreen extends StatelessWidget {
  const NoteDetailScreen({super.key, required this.note});

  final NoteEntity note;

  @override
  Widget build(BuildContext context) {
    final body = note.content ?? note.extractedText ?? '';
    final hasTitle = note.title != null && note.title!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(note.title ?? 'Note'),
        actions: [
          if (note.sourceUrl != null)
            IconButton(
              icon: const Icon(Icons.open_in_browser_rounded),
              tooltip: 'Open source',
              onPressed: () {
                context.showSnackBar(
                  'Opening URL is not available in mock mode',
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingAll16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Metadata row
            _buildMetadata(context),
            AppSpacing.gapV16,

            // Title
            if (hasTitle) ...[
              Text(
                note.title!,
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              AppSpacing.gapV16,
            ],

            // Body
            if (body.isNotEmpty)
              MarkdownRenderer(data: body, shrinkWrap: true)
            else
              Center(
                child: Padding(
                  padding: AppSpacing.paddingAll24,
                  child: Text(
                    'No content available',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),

            AppSpacing.gapV24,

            // Media assets
            if (note.mediaAssets.isNotEmpty) ...[
              Text(
                'Attachments',
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              AppSpacing.gapV8,
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: note.mediaAssets.map((asset) {
                  return Chip(
                    avatar: const Icon(Icons.attach_file_rounded, size: 16),
                    label: Text(
                      asset.split('/').last,
                      style: context.textTheme.labelSmall,
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetadata(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.s12,
      runSpacing: AppSpacing.s4,
      children: [
        _MetadataChip(
          icon: _typeIcon(note.type),
          label: note.type.toUpperCase(),
        ),
        _MetadataChip(
          icon: Icons.schedule_rounded,
          label: note.createdAt.formatDate,
        ),
        if (note.wordCount > 0)
          _MetadataChip(
            icon: Icons.text_fields_rounded,
            label: '${note.wordCount} words',
          ),
        if (note.processed)
          const _MetadataChip(
            icon: Icons.check_circle_rounded,
            label: 'Processed',
            color: AppColors.success,
          ),
      ],
    );
  }

  IconData _typeIcon(String type) {
    return switch (type) {
      'text' => Icons.text_snippet_rounded,
      'url' => Icons.link_rounded,
      'pdf' => Icons.picture_as_pdf_rounded,
      'image' => Icons.image_rounded,
      'audio' => Icons.audiotrack_rounded,
      'video' => Icons.videocam_rounded,
      _ => Icons.note_rounded,
    };
  }
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: chipColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: chipColor),
        ),
      ],
    );
  }
}
