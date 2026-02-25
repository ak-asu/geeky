import '../../../services/local/database.dart';
import '../../../services/local/daos/kg_dao.dart';
import '../domain/concept_entity.dart';
import '../domain/relationship_entity.dart';
import '../domain/graph_node.dart';
import 'concept_dto.dart';
import 'relationship_dto.dart';

class KgRepository {
  KgRepository(this._db);

  final AppDatabase _db;

  KgDao get _kgDao => _db.kgDao;

  // ── Concepts ──────────────────────────────────────────────────────────────

  Future<List<ConceptEntity>> getAllConcepts(String userId) async {
    final rows = await _kgDao.getAllConcepts(userId);
    return rows.map(ConceptDto.fromRow).toList();
  }

  Stream<List<ConceptEntity>> watchAllConcepts(String userId) {
    return _kgDao
        .watchAllConcepts(userId)
        .map((rows) => rows.map(ConceptDto.fromRow).toList());
  }

  // ── Relationships ─────────────────────────────────────────────────────────

  Future<List<RelationshipEntity>> getAllRelationships(String userId) async {
    final rows = await _kgDao.getAllRelationships(userId);
    return rows.map(RelationshipDto.fromRow).toList();
  }

  Stream<List<RelationshipEntity>> watchAllRelationships(String userId) {
    return _kgDao
        .watchAllRelationships(userId)
        .map((rows) => rows.map(RelationshipDto.fromRow).toList());
  }

  // ── Graph nodes (concepts enriched with connection info) ──────────────────

  Future<List<GraphNode>> buildGraphNodes(
    String userId, {
    Set<String> masteredIds = const {},
    Set<String> inProgressIds = const {},
  }) async {
    final concepts = await getAllConcepts(userId);
    final relationships = await getAllRelationships(userId);

    // Build adjacency map (bidirectional)
    final adjacency = <String, Set<String>>{};
    for (final rel in relationships) {
      adjacency.putIfAbsent(rel.sourceId, () => {}).add(rel.targetId);
      adjacency.putIfAbsent(rel.targetId, () => {}).add(rel.sourceId);
    }

    return concepts.map((concept) {
      final connections = adjacency[concept.id]?.toList() ?? [];

      NodeStatus status;
      if (masteredIds.contains(concept.id)) {
        status = NodeStatus.mastered;
      } else if (inProgressIds.contains(concept.id)) {
        status = NodeStatus.inProgress;
      } else {
        status = NodeStatus.unread;
      }

      return GraphNode(
        id: concept.id,
        name: concept.name,
        status: status,
        level: concept.level,
        connections: connections,
      );
    }).toList();
  }
}
