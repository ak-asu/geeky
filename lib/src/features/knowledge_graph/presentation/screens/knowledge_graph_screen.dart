import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/geeky_empty_state.dart';
import '../../../../core/widgets/geeky_shimmer.dart';
import '../../domain/graph_node.dart';
import '../../providers.dart';
import '../widgets/graph_controls.dart';
import '../widgets/graph_visualization.dart';

class KnowledgeGraphScreen extends ConsumerStatefulWidget {
  const KnowledgeGraphScreen({super.key});

  @override
  ConsumerState<KnowledgeGraphScreen> createState() =>
      _KnowledgeGraphScreenState();
}

class _KnowledgeGraphScreenState extends ConsumerState<KnowledgeGraphScreen> {
  String? _selectedNodeId;
  NodeStatus? _filterStatus;
  final _vizKey = GlobalKey<GraphVisualizationState>();

  @override
  Widget build(BuildContext context) {
    final nodesAsync = ref.watch(graphNodesProvider);
    final relationshipsAsync = ref.watch(allRelationshipsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Knowledge Graph',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: context.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: nodesAsync.when(
        loading: () => GeekyShimmer.feedCard(context),
        error: (error, _) => GeekyEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load graph',
          subtitle: error.toString(),
        ),
        data: (nodes) {
          if (nodes.isEmpty) {
            return const GeekyEmptyState(
              icon: Icons.hub_rounded,
              title: 'Knowledge Graph',
              subtitle:
                  'Your knowledge graph will grow as you learn. Create notes and read shorts to populate it.',
            );
          }

          final relationships = relationshipsAsync.value ?? [];

          return Stack(
            children: [
              // Graph visualization (full screen)
              GraphVisualization(
                key: _vizKey,
                nodes: nodes,
                relationships: relationships,
                selectedNodeId: _selectedNodeId,
                filterStatus: _filterStatus,
                onNodeTap: (node) {
                  setState(() {
                    _selectedNodeId =
                        _selectedNodeId == node.id ? null : node.id;
                  });
                },
              ),

              // Controls (top-right)
              Positioned(
                right: AppSpacing.s12,
                top: AppSpacing.s12,
                child: GraphControls(
                  onZoomIn: () => _vizKey.currentState?.zoomIn(),
                  onZoomOut: () => _vizKey.currentState?.zoomOut(),
                  onResetZoom: () => _vizKey.currentState?.resetZoom(),
                  selectedFilter: _filterStatus,
                  onFilterChanged: (filter) {
                    setState(() => _filterStatus = filter);
                  },
                ),
              ),

              // Legend (bottom-left)
              Positioned(
                left: AppSpacing.s12,
                bottom: AppSpacing.s12,
                child: _buildLegend(context),
              ),

              // Selected node detail (bottom)
              if (_selectedNodeId != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildNodeDetail(
                    context,
                    nodes.firstWhere(
                      (n) => n.id == _selectedNodeId,
                      orElse: () => nodes.first,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s8),
      decoration: BoxDecoration(
        color:
            context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _legendItem(context, AppColors.nodeMastered, 'Mastered'),
          const SizedBox(height: 4),
          _legendItem(context, AppColors.nodeInProgress, 'In Progress'),
          const SizedBox(height: 4),
          _legendItem(context, AppColors.nodeUnread, 'Unread'),
          const SizedBox(height: 4),
          _legendItem(context, AppColors.nodeLocked, 'Locked'),
        ],
      ),
    );
  }

  Widget _legendItem(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: context.textTheme.labelSmall?.copyWith(fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildNodeDetail(BuildContext context, GraphNode node) {
    return Container(
      padding: AppSpacing.paddingAll16,
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _statusColor(node.status).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  node.name.isNotEmpty ? node.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: _statusColor(node.status),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            AppSpacing.gapH12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    node.name,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Level ${node.level} \u00B7 ${node.connections.length} connections',
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => setState(() => _selectedNodeId = null),
            ),
          ],
        ),
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
}
