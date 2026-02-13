import 'package:freezed_annotation/freezed_annotation.dart';

part 'graph_node.freezed.dart';
part 'graph_node.g.dart';

enum NodeStatus { mastered, inProgress, unread, locked }

@freezed
abstract class GraphNode with _$GraphNode {
  const factory GraphNode({
    required String id,
    required String name,
    @Default(NodeStatus.unread) NodeStatus status,
    @Default(1) int level,
    @Default([]) List<String> connections,
  }) = _GraphNode;

  factory GraphNode.fromJson(Map<String, dynamic> json) =>
      _$GraphNodeFromJson(json);
}
