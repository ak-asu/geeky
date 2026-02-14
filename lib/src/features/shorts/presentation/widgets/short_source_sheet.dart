import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../routing/route_names.dart';
import '../../../modules/domain/module_entity.dart';
import '../../../modules/providers.dart';
import '../../../notes/domain/note_entity.dart';
import '../../../notes/providers.dart';
import '../../domain/short_entity.dart';

/// Modal bottom sheet showing provenance info for a short:
/// - Source notes (citations) the short was generated from
/// - Module(s) the short belongs to
class ShortSourceSheet extends ConsumerWidget {
  const ShortSourceSheet({super.key, required this.short});

  final ShortEntity short;

  static Future<void> show(BuildContext context, ShortEntity short) {
    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (_) => ShortSourceSheet(short: short),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: AppSpacing.paddingAll16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
              ),
            ),
            AppSpacing.gapV16,

            // Title
            Text(
              'Source Info',
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            AppSpacing.gapV16,

            // Source notes section
            if (short.citations.isNotEmpty) ...[
              const _SectionHeader(
                icon: Icons.description_rounded,
                label: 'Generated from',
              ),
              AppSpacing.gapV8,
              _SourceNotesList(noteIds: short.citations),
              AppSpacing.gapV16,
            ],

            // Module membership section
            const _SectionHeader(
              icon: Icons.view_module_rounded,
              label: 'Appears in modules',
            ),
            AppSpacing.gapV8,
            _ModuleMembershipList(shortId: short.id),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        AppSpacing.gapH8,
        Text(
          label,
          style: context.textTheme.labelMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SourceNotesList extends ConsumerWidget {
  const _SourceNotesList({required this.noteIds});

  final List<String> noteIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(allNotesProvider);
    final allNotes = notesAsync.value ?? <NoteEntity>[];
    final noteMap = {for (final n in allNotes) n.id: n};

    return Column(
      children: noteIds.map((noteId) {
        final note = noteMap[noteId];
        final title = note?.title ?? note?.primaryTopic ?? noteId;
        final typeLabel = note != null ? formatNoteType(note.type) : 'Note';

        return ListTile(
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: const Center(
              child: Icon(
                Icons.description_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ),
          ),
          title: Text(
            title,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            typeLabel,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: note != null
              ? Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: context.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                )
              : null,
          onTap: note != null
              ? () {
                  Navigator.of(context).pop();
                  context.pushNamed(RouteNames.noteDetail, extra: note);
                }
              : null,
        );
      }).toList(),
    );
  }
}

class _ModuleMembershipList extends ConsumerWidget {
  const _ModuleMembershipList({required this.shortId});

  final String shortId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulesAsync = ref.watch(allModulesProvider);
    final allModules = modulesAsync.value ?? <ModuleEntity>[];
    final containing = allModules
        .where((m) => m.shortIds.contains(shortId))
        .toList();

    if (containing.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
        child: Text(
          'Not part of any module yet.',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      children: containing.map((module) {
        final progress = module.totalShorts > 0
            ? '${module.completedShorts}/${module.totalShorts}'
            : '';

        return ListTile(
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: const Center(
              child: Icon(
                Icons.view_module_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ),
          ),
          title: Text(
            module.name,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: progress.isNotEmpty
              ? Text(
                  '$progress completed',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
          trailing: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 12,
            color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          onTap: () {
            Navigator.of(context).pop();
            context.pushNamed(RouteNames.moduleDetail, extra: module);
          },
        );
      }).toList(),
    );
  }
}
