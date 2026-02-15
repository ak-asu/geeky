import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/content_source_entity.dart';

class SourceCard extends StatelessWidget {
  const SourceCard({
    super.key,
    required this.source,
    required this.onTap,
    this.onDelete,
  });

  final ContentSourceEntity source;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s4,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: BorderSide(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: AppSpacing.paddingAll16,
          child: Row(
            children: [
              // Type icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(
                  source.type == 'url'
                      ? Icons.link_rounded
                      : Icons.insert_drive_file_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              AppSpacing.gapH12,

              // Name + URL
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (source.url != null) ...[
                      AppSpacing.gapV4,
                      Text(
                        source.url!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              AppSpacing.gapH8,

              // Health badge
              _HealthBadge(score: source.healthScore),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthBadge extends StatelessWidget {
  const _HealthBadge({this.score});

  final double? score;

  @override
  Widget build(BuildContext context) {
    if (score == null) {
      return const SizedBox.shrink();
    }

    final Color color;
    final IconData icon;
    if (score! >= 0.9) {
      color = AppColors.success;
      icon = Icons.check_circle_rounded;
    } else if (score! >= 0.7) {
      color = AppColors.warning;
      icon = Icons.warning_rounded;
    } else {
      color = AppColors.error;
      icon = Icons.error_rounded;
    }

    return Tooltip(
      message: 'Health: ${(score! * 100).round()}%',
      child: Icon(icon, color: color, size: 20),
    );
  }
}
