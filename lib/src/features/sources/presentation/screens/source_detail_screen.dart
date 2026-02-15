import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/content_source_entity.dart';
import '../../providers.dart';

class SourceDetailScreen extends ConsumerWidget {
  const SourceDetailScreen({super.key, required this.source});

  final ContentSourceEntity source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Source Details',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: context.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Remove source',
            onPressed: () {
              ref.read(sourcesRepositoryProvider).removeSource(source.id);
              ref.invalidate(allSourcesProvider);
              context.pop();
              context.showSnackBar('Source removed');
            },
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.paddingAll16,
        children: [
          // Header
          Container(
            padding: AppSpacing.paddingAll16,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(
                    source.type == 'url'
                        ? Icons.link_rounded
                        : Icons.insert_drive_file_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                AppSpacing.gapH16,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.name,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      AppSpacing.gapV4,
                      Text(
                        source.type.toUpperCase(),
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          AppSpacing.gapV24,

          // Details
          _DetailRow(
            label: 'Status',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  source.status == 'active'
                      ? Icons.check_circle_rounded
                      : Icons.pause_circle_rounded,
                  size: 16,
                  color: source.status == 'active'
                      ? AppColors.success
                      : AppColors.warning,
                ),
                AppSpacing.gapH4,
                Text(
                  source.status[0].toUpperCase() + source.status.substring(1),
                  style: context.textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          if (source.url != null)
            _DetailRow(
              label: 'URL',
              child: Text(
                source.url!,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),

          if (source.healthScore != null)
            _DetailRow(
              label: 'Health Score',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 100,
                    child: LinearProgressIndicator(
                      value: source.healthScore!,
                      backgroundColor:
                          context.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                        source.healthScore! >= 0.9
                            ? AppColors.success
                            : source.healthScore! >= 0.7
                            ? AppColors.warning
                            : AppColors.error,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  AppSpacing.gapH8,
                  Text(
                    '${(source.healthScore! * 100).round()}%',
                    style: context.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

          if (source.lastChecked != null)
            _DetailRow(
              label: 'Last Checked',
              child: Text(
                _formatDate(source.lastChecked!),
                style: context.textTheme.bodyMedium,
              ),
            ),

          _DetailRow(
            label: 'Added',
            child: Text(
              _formatDate(source.createdAt),
              style: context.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
