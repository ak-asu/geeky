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

    // Create graph nodes
    final nodeMap = <String, Node>{};
    for (final graphNode in filteredNodes) {
      final node = Node.Id(graphNode.id);
      nodeMap[graphNode.id] = node;
      graph.addNode(node);
    }

    // Create edges from relationships
    for (final rel in widget.relationships) {
      final source = nodeMap[rel.sourceId];
      final target = nodeMap[rel.targetId];
      if (source != null && target != null) {
        graph.addEdge(source, target);
      }
    }

    // Ensure nodes without edges are still in the graph
    for (final graphNode in filteredNodes) {
      if (!nodeMap.containsKey(graphNode.id)) continue;
      // Node is already added above
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
      return const Center(
        child: Text('No concepts to display'),
      );
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
