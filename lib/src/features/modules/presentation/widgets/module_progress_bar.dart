import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class ModuleProgressBar extends StatelessWidget {
  const ModuleProgressBar({
    super.key,
    required this.completed,
    required this.total,
    this.height = 6,
    this.showLabel = false,
  });

  final int completed;
  final int total;
  final double height;
  final bool showLabel;

  double get _progress => total > 0 ? completed / total : 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: height,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              _progress >= 1.0 ? AppColors.success : AppColors.primary,
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: AppSpacing.s4),
          Text(
            '$completed / $total shorts',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
