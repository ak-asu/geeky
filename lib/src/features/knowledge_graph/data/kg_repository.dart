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

  // --- Concepts ---

  Future<List<ConceptEntity>> getAllConcepts() async {
    final rows = await _kgDao.getAllConcepts();
    return rows.map(ConceptDto.fromRow).toList();
  }

  Stream<List<ConceptEntity>> watchAllConcepts() {
    return _kgDao.watchAllConcepts().map(
      (rows) => rows.map(ConceptDto.fromRow).toList(),
    );
  }

  // --- Relationships ---

  Future<List<RelationshipEntity>> getAllRelationships() async {
    final rows = await _kgDao.getAllRelationships();
    return rows.map(RelationshipDto.fromRow).toList();
  }

  Stream<List<RelationshipEntity>> watchAllRelationships() {
    return _kgDao.watchAllRelationships().map(
      (rows) => rows.map(RelationshipDto.fromRow).toList(),
    );
  }

  // --- Graph nodes (concepts enriched with connection info) ---

  Future<List<GraphNode>> buildGraphNodes({
    Set<String> masteredIds = const {},
    Set<String> inProgressIds = const {},
  }) async {
    final concepts = await getAllConcepts();
    final relationships = await getAllRelationships();

    // Build adjacency map
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
