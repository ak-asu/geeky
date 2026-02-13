import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class TopicChip extends StatelessWidget {
  const TopicChip({
    super.key,
    required this.label,
    this.onTap,
    this.isSelected = false,
    this.color,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isSelected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor.withValues(alpha: 0.15)
              : context.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: isSelected
                ? chipColor.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: context.textTheme.labelMedium?.copyWith(
            color: isSelected
                ? chipColor
                : context.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
