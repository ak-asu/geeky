import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Expandable follow-up question prompts at the bottom of a short card.
class ExplorationPromptsList extends StatefulWidget {
  const ExplorationPromptsList({
    super.key,
    required this.prompts,
    this.onPromptTap,
  });

  final List<String> prompts;
  final ValueChanged<String>? onPromptTap;

  @override
  State<ExplorationPromptsList> createState() => _ExplorationPromptsListState();
}

class _ExplorationPromptsListState extends State<ExplorationPromptsList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.prompts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s8,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.explore_rounded,
                  size: 16,
                  color: AppColors.primary.withValues(alpha: 0.8),
                ),
                AppSpacing.gapH8,
                Text(
                  'Explore Further',
                  style: context.textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: AppColors.primary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            child: Column(
              children: widget.prompts
                  .map((prompt) => _PromptTile(
                        prompt: prompt,
                        onTap: () => widget.onPromptTap?.call(prompt),
                      ))
                  .toList(),
            ),
          ),
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

class _PromptTile extends StatelessWidget {
  const _PromptTile({required this.prompt, this.onTap});

  final String prompt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.s8,
          horizontal: AppSpacing.s4,
        ),
        child: Row(
          children: [
            Icon(
              Icons.lightbulb_outline_rounded,
              size: 16,
              color: context.colorScheme.onSurfaceVariant,
            ),
            AppSpacing.gapH8,
            Expanded(
              child: Text(
                prompt,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: context.colorScheme.onSurfaceVariant.withValues(
                alpha: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
