import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers/database_provider.dart';
import 'data/kg_repository.dart';
import 'domain/concept_entity.dart';
import 'domain/graph_node.dart';
import 'domain/relationship_entity.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
KgRepository kgRepository(Ref ref) {
  return KgRepository(ref.read(appDatabaseProvider));
}

/// Watches all concepts from Drift as a stream.
@riverpod
Stream<List<ConceptEntity>> allConcepts(Ref ref) {
  return ref.watch(kgRepositoryProvider).watchAllConcepts();
}

/// Watches all relationships from Drift as a stream.
@riverpod
Stream<List<RelationshipEntity>> allRelationships(Ref ref) {
  return ref.watch(kgRepositoryProvider).watchAllRelationships();
}

/// Builds graph nodes with status information.
@riverpod
Future<List<GraphNode>> graphNodes(Ref ref) {
  return ref.watch(kgRepositoryProvider).buildGraphNodes();
}
