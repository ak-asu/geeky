import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../routing/route_names.dart';
import '../../domain/short_entity.dart';
import '../../presentation/screens/shorts_feed_screen.dart';

/// Bottom sheet that lists shorts related to the current one.
class RelatedShortsSheet extends StatelessWidget {
  const RelatedShortsSheet({super.key, required this.relatedShorts});

  final List<ShortEntity> relatedShorts;

  /// Convenience factory: resolves [relatedIds] against [allShorts] and shows
  /// the sheet. Silently shows an empty state if no matches are found.
  static Future<void> show(
    BuildContext context, {
    required List<String> relatedIds,
    required List<ShortEntity> allShorts,
  }) {
    final map = {for (final s in allShorts) s.id: s};
    final resolved = [
      for (final id in relatedIds)
        if (map.containsKey(id)) map[id]!,
    ];

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (_) => RelatedShortsSheet(relatedShorts: resolved),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Column(
          children: [
            _buildHandle(context),
            _buildHeader(context),
            Expanded(
              child: relatedShorts.isEmpty
                  ? _buildEmpty(context)
                  : _buildList(context, scrollController),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHandle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.s12,
        bottom: AppSpacing.s4,
      ),
      child: Center(
        child: Container(
          width: 32,
          height: 4,
          decoration: BoxDecoration(
            color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s8,
      ),
      child: Row(
        children: [
          const Icon(Icons.hub_rounded, size: 20, color: AppColors.primary),
          AppSpacing.gapH8,
          Text(
            'Related Shorts',
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingAll24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hub_outlined,
              size: 48,
              color: context.colorScheme.onSurfaceVariant.withValues(
                alpha: 0.4,
              ),
            ),
            AppSpacing.gapV16,
            Text(
              'No related shorts yet',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, ScrollController scrollController) {
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s4,
        AppSpacing.s16,
        AppSpacing.s24,
      ),
      itemCount: relatedShorts.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final short = relatedShorts[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          title: Text(
            short.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: short.topics.isNotEmpty
              ? Text(
                  short.topics.first,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
          onTap: () {
            Navigator.of(context).pop();
            context.pushNamed(
              RouteNames.shortsFeed,
              extra: ShortsFeedParams(filterShortIds: [short.id]),
            );
          },
        );
      },
    );
  }
}
