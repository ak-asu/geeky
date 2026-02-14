import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/graph_node.dart';

class GraphControls extends StatelessWidget {
  const GraphControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
    this.selectedFilter,
    this.onFilterChanged,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;
  final NodeStatus? selectedFilter;
  final ValueChanged<NodeStatus?>? onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Zoom controls
        Container(
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.9,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ControlButton(
                icon: Icons.add_rounded,
                onTap: onZoomIn,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSpacing.radiusMd),
                ),
              ),
              Divider(
                height: 1,
                color: context.colorScheme.outlineVariant.withValues(
                  alpha: 0.3,
                ),
              ),
              _ControlButton(icon: Icons.remove_rounded, onTap: onZoomOut),
              Divider(
                height: 1,
                color: context.colorScheme.outlineVariant.withValues(
                  alpha: 0.3,
                ),
              ),
              _ControlButton(
                icon: Icons.fit_screen_rounded,
                onTap: onResetZoom,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppSpacing.radiusMd),
                ),
              ),
            ],
          ),
        ),
        AppSpacing.gapV12,

        // Filter dropdown
        Container(
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.9,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: PopupMenuButton<NodeStatus?>(
            onSelected: onFilterChanged,
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('All nodes')),
              PopupMenuItem(
                value: NodeStatus.mastered,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.nodeMastered,
                        shape: BoxShape.circle,
                      ),
                    ),
                    AppSpacing.gapH8,
                    const Text('Mastered'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: NodeStatus.inProgress,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.nodeInProgress,
                        shape: BoxShape.circle,
                      ),
                    ),
                    AppSpacing.gapH8,
                    const Text('In Progress'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: NodeStatus.unread,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.nodeUnread,
                        shape: BoxShape.circle,
                      ),
                    ),
                    AppSpacing.gapH8,
                    const Text('Unread'),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s8),
              child: Icon(
                Icons.filter_list_rounded,
                size: 22,
                color: selectedFilter != null
                    ? AppColors.primary
                    : context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.borderRadius,
  });

  final IconData icon;
  final VoidCallback onTap;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: borderRadius,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s8),
        child: Icon(
          icon,
          size: 22,
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
