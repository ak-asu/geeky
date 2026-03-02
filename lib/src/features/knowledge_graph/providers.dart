import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/api_service.dart';
import '../../core/providers/database_provider.dart';
import '../auth/providers.dart';
import 'data/kg_repository.dart';
import 'domain/concept_entity.dart';
import 'domain/graph_node.dart';
import 'domain/relationship_entity.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
KgRepository kgRepository(Ref ref) {
  return KgRepository(
    ref.read(appDatabaseProvider),
    ref.read(apiServiceProvider),
  );
}

/// Watches all concepts from Drift as a stream.
///
/// Kept alive so the stream persists across navigation.
/// Triggers an API fetch on first build to hydrate Drift; the stream
/// reacts to the resulting writes automatically.
@Riverpod(keepAlive: true)
Stream<List<ConceptEntity>> allConcepts(Ref ref) {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  final repo = ref.watch(kgRepositoryProvider);
  if (userId.isNotEmpty) {
    repo.fetchAndCacheAll(userId).ignore();
  }
  return repo.watchAllConcepts(userId);
}

/// Watches all relationships from Drift as a stream.
///
/// Kept alive so the stream persists across navigation.
@Riverpod(keepAlive: true)
Stream<List<RelationshipEntity>> allRelationships(Ref ref) {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  return ref.watch(kgRepositoryProvider).watchAllRelationships(userId);
}

/// Builds graph nodes with status information.
///
/// Derives from [allConceptsProvider] and [allRelationshipsProvider] so it
/// rebuilds reactively whenever Drift is updated by the background fetch.
@riverpod
Future<List<GraphNode>> graphNodes(Ref ref) async {
  // Await the first emission from each Drift-backed stream.
  // allConceptsProvider also triggers the background API fetch that populates Drift.
  final concepts = await ref.watch(allConceptsProvider.future);
  final relationships = await ref.watch(allRelationshipsProvider.future);
  return ref
      .watch(kgRepositoryProvider)
      .buildGraphNodesFromData(concepts, relationships);
}
