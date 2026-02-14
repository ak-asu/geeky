import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/module_entity.dart';
import 'module_progress_bar.dart';

class ModuleCard extends StatelessWidget {
  const ModuleCard({
    super.key,
    required this.module,
    required this.onTap,
  });

  final ModuleEntity module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = module.totalShorts > 0
        ? module.completedShorts / module.totalShorts
        : 0.0;
    final isComplete = progress >= 1.0;
    final topicLabel =
        module.topics.isNotEmpty ? module.topics.first : module.type;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: AppSpacing.paddingAll16,
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: isComplete
                ? AppColors.success.withValues(alpha: 0.3)
                : context.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + type badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(
                    isComplete
                        ? Icons.check_circle_rounded
                        : Icons.view_module_rounded,
                    size: 20,
                    color: isComplete ? AppColors.success : AppColors.primary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text(
                    topicLabel,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.gapV12,

            // Name
            Text(
              module.name,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            AppSpacing.gapV4,

            // Description
            if (module.description != null)
              Text(
                module.description!,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

            const Spacer(),

            // Progress bar
            ModuleProgressBar(
              completed: module.completedShorts,
              total: module.totalShorts,
            ),
            AppSpacing.gapV4,

            // Progress label
            Text(
              '${module.completedShorts}/${module.totalShorts} shorts',
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
