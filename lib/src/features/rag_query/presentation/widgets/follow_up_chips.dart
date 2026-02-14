import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class FollowUpChips extends StatelessWidget {
  const FollowUpChips({
    super.key,
    required this.questions,
    required this.onTap,
  });

  final List<String> questions;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Follow-up questions',
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        AppSpacing.gapV8,
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: questions.map((q) {
            return ActionChip(
              label: Text(
                q,
                style: context.textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                ),
              ),
              avatar: Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: AppColors.primary.withValues(alpha: 0.7),
              ),
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
              onPressed: () => onTap(q),
            );
          }).toList(),
        ),
      ],
    );
  }
}
