import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../providers.dart';

class SearchFilterBar extends ConsumerWidget {
  const SearchFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicFilter = ref.watch(searchTopicFilterProvider);
    final difficultyFilter = ref.watch(searchDifficultyFilterProvider);
    final topicsAsync = ref.watch(availableTopicsProvider);

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.paddingH16,
        children: [
          // Difficulty filter
          _FilterChip(
            label: difficultyFilter ?? 'Difficulty',
            isActive: difficultyFilter != null,
            onTap: () => _showDifficultyPicker(context, ref, difficultyFilter),
          ),
          AppSpacing.gapH8,

          // Topic filter
          topicsAsync.when(
            data: (topics) => _FilterChip(
              label: topicFilter ?? 'Topic',
              isActive: topicFilter != null,
              onTap: () => _showTopicPicker(context, ref, topics, topicFilter),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          // Clear filters
          if (topicFilter != null || difficultyFilter != null) ...[
            AppSpacing.gapH8,
            ActionChip(
              label: Text(
                'Clear',
                style: context.textTheme.labelSmall?.copyWith(
                  color: AppColors.error,
                ),
              ),
              side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
              onPressed: () {
                ref.read(searchTopicFilterProvider.notifier).set(null);
                ref.read(searchDifficultyFilterProvider.notifier).set(null);
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showDifficultyPicker(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) {
    final difficulties = ['beginner', 'intermediate', 'advanced'];
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSpacing.gapV8,
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: context.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
            ),
            AppSpacing.gapV16,
            ...difficulties.map(
              (d) => ListTile(
                title: Text(
                  d[0].toUpperCase() + d.substring(1),
                  style: context.textTheme.bodyMedium,
                ),
                trailing: current == d
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  ref
                      .read(searchDifficultyFilterProvider.notifier)
                      .set(current == d ? null : d);
                  Navigator.pop(ctx);
                },
              ),
            ),
            AppSpacing.gapV16,
          ],
        ),
      ),
    );
  }

  void _showTopicPicker(
    BuildContext context,
    WidgetRef ref,
    List<String> topics,
    String? current,
  ) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSpacing.gapV8,
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: context.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
            ),
            AppSpacing.gapV16,
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: topics.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(topics[i], style: context.textTheme.bodyMedium),
                  trailing: current == topics[i]
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.primary,
                        )
                      : null,
                  onTap: () {
                    ref
                        .read(searchTopicFilterProvider.notifier)
                        .set(current == topics[i] ? null : topics[i]);
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ),
            AppSpacing.gapV16,
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: isActive
                  ? AppColors.primary
                  : context.colorScheme.onSurfaceVariant,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          AppSpacing.gapH4,
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: isActive
                ? AppColors.primary
                : context.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      side: BorderSide(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.5)
            : context.colorScheme.outlineVariant,
      ),
      backgroundColor: isActive
          ? AppColors.primary.withValues(alpha: 0.08)
          : null,
      onPressed: onTap,
    );
  }
}
