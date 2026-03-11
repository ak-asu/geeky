import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_service.dart';
import '../../../services/local/database.dart';
import '../../../services/local/daos/kg_dao.dart';
import '../domain/concept_entity.dart';
import '../domain/relationship_entity.dart';
import '../domain/graph_node.dart';
import 'concept_dto.dart';
import 'relationship_dto.dart';

class KgRepository {
  KgRepository(this._db, this._api);

  final AppDatabase _db;
  final ApiService _api;

  KgDao get _kgDao => _db.kgDao;

  // ── Remote fetch + local cache ─────────────────────────────────────────────

  /// Fetches concepts and relationships from the backend and caches them in
  /// Drift. Both calls are run in parallel; individual failures are swallowed
  /// so the existing Drift cache is used as a fallback.
  Future<void> fetchAndCacheAll(String userId) =>
      Future.wait([_fetchConcepts(userId), _fetchRelationships(userId)]);

  Future<void> _fetchConcepts(String userId) async {
    try {
      final concepts = await _api.getList(
        '${ApiConstants.knowledgeGraph}/nodes',
        (json) => ConceptEntity.fromJson(json as Map<String, dynamic>),
        queryParams: {'limit': '200'},
      );
      await _kgDao.insertConcepts(
        concepts.map((c) => ConceptDto.toCompanion(c, userId)).toList(),
      );
    } catch (_) {}
  }

  Future<void> _fetchRelationships(String userId) async {
    try {
      final relationships = await _api.getList(
        '${ApiConstants.knowledgeGraph}/edges',
        (json) => RelationshipEntity.fromJson(json as Map<String, dynamic>),
        queryParams: {'limit': '200'},
      );
      await _kgDao.insertRelationships(
        relationships
            .map((r) => RelationshipDto.toCompanion(r, userId))
            .toList(),
      );
    } catch (_) {}
  }

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

  /// Builds [GraphNode]s from pre-loaded data — used by the provider so the
  /// reactive Drift streams drive the graph rather than one-shot queries.
  List<GraphNode> buildGraphNodesFromData(
    List<ConceptEntity> concepts,
    List<RelationshipEntity> relationships, {
    Set<String> masteredIds = const {},
    Set<String> inProgressIds = const {},
  }) => _toGraphNodes(concepts, relationships, masteredIds, inProgressIds);

  /// Convenience overload that reads concepts/relationships from Drift once.
  Future<List<GraphNode>> buildGraphNodes(
    String userId, {
    Set<String> masteredIds = const {},
    Set<String> inProgressIds = const {},
  }) async {
    final concepts = await getAllConcepts(userId);
    final relationships = await getAllRelationships(userId);
    return _toGraphNodes(concepts, relationships, masteredIds, inProgressIds);
  }

  List<GraphNode> _toGraphNodes(
    List<ConceptEntity> concepts,
    List<RelationshipEntity> relationships,
    Set<String> masteredIds,
    Set<String> inProgressIds,
  ) {
    // Build adjacency map (bidirectional)
    final adjacency = <String, Set<String>>{};
    for (final rel in relationships) {
      adjacency.putIfAbsent(rel.sourceId, () => {}).add(rel.targetId);
      adjacency.putIfAbsent(rel.targetId, () => {}).add(rel.sourceId);
    }

    return concepts.map((concept) {
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
        connections: adjacency[concept.id]?.toList() ?? [],
      );
    }).toList();
  }
}
