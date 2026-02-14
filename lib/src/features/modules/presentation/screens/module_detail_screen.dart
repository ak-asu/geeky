import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../routing/route_names.dart';
import '../../domain/module_entity.dart';
import '../../../shorts/providers.dart';
import '../../../shorts/domain/short_entity.dart';
import '../../../shorts/presentation/screens/shorts_feed_screen.dart';
import '../widgets/module_progress_bar.dart';

class ModuleDetailScreen extends ConsumerWidget {
  const ModuleDetailScreen({super.key, required this.module});

  final ModuleEntity module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doneSet = ref.watch(shortsFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          module.name,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: context.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: module.shortIds.isNotEmpty
          ? FloatingActionButton.small(
              onPressed: () => context.pushNamed(
                RouteNames.shortsFeed,
                extra: ShortsFeedParams(
                  filterShortIds: module.shortIds,
                  title: module.name,
                ),
              ),
              child: const Icon(Icons.play_arrow_rounded),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: ListView(
        padding: AppSpacing.paddingAll16,
        children: [
          // Module info header
          _buildHeader(context),
          AppSpacing.gapV24,

          // Progress
          ModuleProgressBar(
            completed: module.completedShorts,
            total: module.totalShorts,
            height: 8,
            showLabel: true,
          ),
          AppSpacing.gapV24,

          // Shorts list
          Text(
            'Shorts in this module',
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.gapV12,
          _buildShortsList(context, ref, doneSet),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Topics
        if (module.topics.isNotEmpty)
          Wrap(
            spacing: AppSpacing.s8,
            children: module.topics
                .map(
                  (t) => Chip(
                    label: Text(
                      t,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    side: BorderSide.none,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
        if (module.description != null) ...[
          AppSpacing.gapV12,
          Text(
            module.description!,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        AppSpacing.gapV8,
        Row(
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 16,
              color: context.colorScheme.onSurfaceVariant,
            ),
            AppSpacing.gapH4,
            Text(
              '~${module.estimatedMinutesRemaining.round()} min remaining',
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            AppSpacing.gapH16,
            Icon(
              Icons.auto_stories_rounded,
              size: 16,
              color: context.colorScheme.onSurfaceVariant,
            ),
            AppSpacing.gapH4,
            Text(
              '${module.totalShorts} shorts',
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShortsList(
    BuildContext context,
    WidgetRef ref,
    Set<String> doneSet,
  ) {
    if (module.shortIds.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s32),
        child: Center(
          child: Text(
            'No shorts in this module yet.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // Use shorts from the allShorts provider if available
    final shortsAsync = ref.watch(allShortsProvider);
    final allShorts = shortsAsync.value ?? <ShortEntity>[];

    return Column(
      children: module.shortIds.asMap().entries.map((entry) {
        final index = entry.key;
        final shortId = entry.value;
        final isDone = doneSet.contains(shortId);

        // Find the short entity for this ID
        final shortEntity = allShorts.where((s) => s.id == shortId).firstOrNull;
        final title = shortEntity?.title ?? 'Short ${index + 1}';
        final summary = shortEntity?.summary ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.s8),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: isDone
                  ? AppColors.success.withValues(alpha: 0.3)
                  : context.colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: ListTile(
            onTap: () => context.pushNamed(
              RouteNames.shortsFeed,
              extra: ShortsFeedParams(
                filterShortIds: module.shortIds,
                initialIndex: index,
                title: module.name,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s4,
            ),
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDone
                    ? AppColors.success.withValues(alpha: 0.1)
                    : context.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isDone
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: AppColors.success,
                      )
                    : Text(
                        '${index + 1}',
                        style: context.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
            title: Text(
              title,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                decoration: isDone ? TextDecoration.lineThrough : null,
                color: isDone ? context.colorScheme.onSurfaceVariant : null,
              ),
            ),
            subtitle: summary.isNotEmpty
                ? Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  )
                : null,
            trailing: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: context.colorScheme.onSurfaceVariant.withValues(
                alpha: 0.5,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
