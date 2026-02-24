import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/datetime_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/geeky_empty_state.dart';
import '../../../../core/widgets/geeky_shimmer.dart';
import '../../../../routing/route_names.dart';
import '../../domain/note_entity.dart';
import '../../providers.dart';

class NotesListScreen extends ConsumerWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(allNotesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic_rounded),
            tooltip: 'Voice memo',
            onPressed: () => context.pushNamed(RouteNames.voiceMemo),
          ),
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'Upload media',
            onPressed: () => context.pushNamed(RouteNames.uploadMedia),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pushNamed(RouteNames.createNote),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: notesAsync.when(
        loading: () => ListView.builder(
          itemCount: 6,
          itemBuilder: (_, _) => GeekyShimmer.listItem(),
        ),
        error: (e, _) => GeekyEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Failed to load notes',
          subtitle: e.toString(),
        ),
        data: (notes) {
          if (notes.isEmpty) {
            return GeekyEmptyState(
              icon: Icons.note_add_rounded,
              title: 'No notes yet',
              subtitle: 'Create your first note to start learning.',
              actionLabel: 'Create Note',
              onAction: () => context.pushNamed(RouteNames.createNote),
            );
          }

          return GridView.builder(
            padding: AppSpacing.paddingAll16,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.s12,
              crossAxisSpacing: AppSpacing.s12,
              childAspectRatio: 0.85,
            ),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              return _NoteGridCard(
                note: notes[index],
                onTap: () => context.pushNamed(
                  RouteNames.noteDetail,
                  extra: notes[index],
                ),
                onDelete: () => _confirmDelete(context, ref, notes[index]),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, NoteEntity note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note?'),
        content: Text(
          'This will permanently delete "${note.title ?? 'Untitled note'}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(notesRepositoryProvider).deleteNote(note.id);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _NoteGridCard extends StatelessWidget {
  const _NoteGridCard({
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  final NoteEntity note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = note.title ?? 'Untitled';
    final preview = note.content ?? note.extractedText ?? '';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        child: Padding(
          padding: AppSpacing.paddingAll16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type icon
              Icon(_typeIcon(note.type), size: 20, color: AppColors.primary),
              AppSpacing.gapV8,

              // Title
              Text(
                title,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              AppSpacing.gapV4,

              // Preview
              Expanded(
                child: Text(
                  preview,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Footer
              Row(
                children: [
                  Text(
                    note.createdAt.timeAgo,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (note.processed)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: AppColors.success.withValues(alpha: 0.7),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
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
