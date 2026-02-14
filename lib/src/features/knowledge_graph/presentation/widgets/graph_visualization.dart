import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/graph_node.dart';
import '../../domain/relationship_entity.dart';
import 'graph_node_widget.dart';

class GraphVisualization extends StatefulWidget {
  const GraphVisualization({
    super.key,
    required this.nodes,
    required this.relationships,
    this.selectedNodeId,
    this.onNodeTap,
    this.filterStatus,
  });

  final List<GraphNode> nodes;
  final List<RelationshipEntity> relationships;
  final String? selectedNodeId;
  final ValueChanged<GraphNode>? onNodeTap;
  final NodeStatus? filterStatus;

  @override
  GraphVisualizationState createState() => GraphVisualizationState();
}

class GraphVisualizationState extends State<GraphVisualization> {
  final _transformationController = TransformationController();

  Graph _graph = Graph();
  BuchheimWalkerConfiguration _builder = BuchheimWalkerConfiguration();

  @override
  void initState() {
    super.initState();
    _buildGraph();
  }

  @override
  void didUpdateWidget(covariant GraphVisualization oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nodes != widget.nodes ||
        oldWidget.relationships != widget.relationships ||
        oldWidget.filterStatus != widget.filterStatus) {
      _buildGraph();
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _buildGraph() {
    final graph = Graph();

    // Filter nodes if a filter is active
    final filteredNodes = widget.filterStatus != null
        ? widget.nodes.where((n) => n.status == widget.filterStatus).toList()
        : widget.nodes;

    if (filteredNodes.isEmpty) {
      setState(() => _graph = graph);
      return;
    }

    // Create graph nodes
    final nodeMap = <String, Node>{};
    final nodeIds = <String>{};
    for (final graphNode in filteredNodes) {
      final node = Node.Id(graphNode.id);
      nodeMap[graphNode.id] = node;
      nodeIds.add(graphNode.id);
      graph.addNode(node);
    }

    // Build adjacency list from relationships (only for filtered node IDs)
    final adjacency = <String, List<String>>{};
    for (final rel in widget.relationships) {
      if (!nodeIds.contains(rel.sourceId) || !nodeIds.contains(rel.targetId)) {
        continue;
      }
      adjacency.putIfAbsent(rel.sourceId, () => []).add(rel.targetId);
    }

    // BFS spanning tree to eliminate cycles
    // BuchheimWalkerAlgorithm requires a strict tree structure
    final visited = <String>{};
    final queue = <String>[];

    // Start from nodes that have no incoming edges (roots), or first node
    final hasIncoming = <String>{};
    for (final rel in widget.relationships) {
      if (nodeIds.contains(rel.targetId) && nodeIds.contains(rel.sourceId)) {
        hasIncoming.add(rel.targetId);
      }
    }
    final roots = nodeIds.where((id) => !hasIncoming.contains(id)).toList();
    if (roots.isEmpty && nodeIds.isNotEmpty) {
      roots.add(nodeIds.first);
    }

    // BFS from each root to build spanning tree edges
    for (final root in roots) {
      if (visited.contains(root)) continue;
      visited.add(root);
      queue.add(root);

      while (queue.isNotEmpty) {
        final current = queue.removeAt(0);
        final children = adjacency[current] ?? [];
        for (final child in children) {
          if (visited.contains(child)) continue;
          visited.add(child);
          queue.add(child);
          // Add only tree edge (no cycles)
          graph.addEdge(nodeMap[current]!, nodeMap[child]!);
        }
      }
    }

    // Connect any remaining disconnected nodes to the first root
    // so the tree algorithm has a single connected component
    final firstRoot = roots.first;
    for (final id in nodeIds) {
      if (!visited.contains(id)) {
        visited.add(id);
        graph.addEdge(nodeMap[firstRoot]!, nodeMap[id]!);
      }
    }

    _builder = BuchheimWalkerConfiguration()
      ..siblingSeparation = 60
      ..levelSeparation = 80
      ..subtreeSeparation = 80
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM;

    setState(() {
      _graph = graph;
    });
  }

  void zoomIn() {
    final matrix = _transformationController.value.clone();
    matrix.scaleByDouble(1.2, 1.2, 1.0, 1.0);
    _transformationController.value = matrix;
  }

  void zoomOut() {
    final matrix = _transformationController.value.clone();
    matrix.scaleByDouble(0.8, 0.8, 1.0, 1.0);
    _transformationController.value = matrix;
  }

  void resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    if (_graph.nodeCount() == 0) {
      return const Center(child: Text('No concepts to display'));
    }

    return InteractiveViewer(
      constrained: false,
      transformationController: _transformationController,
      boundaryMargin: const EdgeInsets.all(200),
      minScale: 0.3,
      maxScale: 3.0,
      child: GraphView(
        graph: _graph,
        algorithm: BuchheimWalkerAlgorithm(
          _builder,
          TreeEdgeRenderer(_builder),
        ),
        paint: Paint()
          ..color = AppColors.primary.withValues(alpha: 0.3)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
        builder: (Node node) {
          final id = node.key?.value as String?;
          final graphNode = widget.nodes.where((n) => n.id == id).firstOrNull;

          if (graphNode == null) {
            return const SizedBox(width: 30, height: 30);
          }

          return GraphNodeWidget(
            node: graphNode,
            isSelected: widget.selectedNodeId == graphNode.id,
            onTap: () => widget.onNodeTap?.call(graphNode),
          );
        },
      ),
    );
  }
}
