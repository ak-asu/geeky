import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Horizontal scrollable chips for KG navigation from a short.
/// Shows related concepts that the user can tap to explore.
class NavigationOptions extends StatelessWidget {
  const NavigationOptions({
    super.key,
    required this.conceptNames,
    this.onConceptTap,
  });

  final List<String> conceptNames;
  final ValueChanged<String>? onConceptTap;

  @override
  Widget build(BuildContext context) {
    if (conceptNames.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
        itemCount: conceptNames.length,
        separatorBuilder: (_, _) => AppSpacing.gapH8,
        itemBuilder: (context, index) {
          final name = conceptNames[index];
          return ActionChip(
            label: Text(
              name,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: AppColors.primary.withValues(alpha: 0.08),
            side: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            onPressed: () => onConceptTap?.call(name),
            avatar: Icon(
              Icons.hub_rounded,
              size: 14,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
          );
        },
      ),
    );
  }
}
