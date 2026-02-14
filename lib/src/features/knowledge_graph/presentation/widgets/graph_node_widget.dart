import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/graph_node.dart';

class GraphNodeWidget extends StatelessWidget {
  const GraphNodeWidget({
    super.key,
    required this.node,
    this.isSelected = false,
    this.onTap,
  });

  final GraphNode node;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(node.status);
    final size = _nodeSize(node.level);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isSelected ? 1.0 : 0.8),
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Center(
              child: Text(
                node.name.isNotEmpty ? node.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: size * 0.35,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          SizedBox(
            width: size + 24,
            child: Text(
              node.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.labelSmall?.copyWith(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: context.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(NodeStatus status) {
    return switch (status) {
      NodeStatus.mastered => AppColors.nodeMastered,
      NodeStatus.inProgress => AppColors.nodeInProgress,
      NodeStatus.unread => AppColors.nodeUnread,
      NodeStatus.locked => AppColors.nodeLocked,
    };
  }

  double _nodeSize(int level) {
    return switch (level) {
      1 => 40.0,
      2 => 34.0,
      3 => 28.0,
      _ => 32.0,
    };
  }
}
