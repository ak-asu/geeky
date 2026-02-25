import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers/database_provider.dart';
import '../auth/providers.dart';
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
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  return ref.watch(kgRepositoryProvider).watchAllConcepts(userId);
}

/// Watches all relationships from Drift as a stream.
@riverpod
Stream<List<RelationshipEntity>> allRelationships(Ref ref) {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  return ref.watch(kgRepositoryProvider).watchAllRelationships(userId);
}

/// Builds graph nodes with status information.
@riverpod
Future<List<GraphNode>> graphNodes(Ref ref) {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  return ref.watch(kgRepositoryProvider).buildGraphNodes(userId);
}
