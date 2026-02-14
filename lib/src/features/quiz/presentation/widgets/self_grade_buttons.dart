import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/fsrs_scheduler.dart';

class SelfGradeButtons extends StatelessWidget {
  const SelfGradeButtons({
    super.key,
    required this.onGrade,
    this.enabled = true,
  });

  final ValueChanged<FSRSGrade> onGrade;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GradeButton(
          label: 'Again',
          subtitle: '<10m',
          color: AppColors.error,
          onTap: enabled ? () => _grade(FSRSGrade.again) : null,
        ),
        AppSpacing.gapH8,
        _GradeButton(
          label: 'Hard',
          subtitle: '1d',
          color: AppColors.warning,
          onTap: enabled ? () => _grade(FSRSGrade.hard) : null,
        ),
        AppSpacing.gapH8,
        _GradeButton(
          label: 'Good',
          subtitle: '3d',
          color: AppColors.primary,
          onTap: enabled ? () => _grade(FSRSGrade.good) : null,
        ),
        AppSpacing.gapH8,
        _GradeButton(
          label: 'Easy',
          subtitle: '7d',
          color: AppColors.success,
          onTap: enabled ? () => _grade(FSRSGrade.easy) : null,
        ),
      ],
    );
  }

  void _grade(FSRSGrade grade) {
    HapticFeedback.mediumImpact();
    onGrade(grade);
  }
}

class _GradeButton extends StatelessWidget {
  const _GradeButton({
    required this.label,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: color.withValues(alpha: onTap != null ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.s12,
              horizontal: AppSpacing.s4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: onTap != null ? color : color.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant.withValues(
                      alpha: onTap != null ? 0.7 : 0.3,
                    ),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
