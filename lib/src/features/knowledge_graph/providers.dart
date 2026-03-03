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

/// One-shot API sync for the knowledge graph (keepAlive = once per session).
///
/// Errors are swallowed inside [KgRepository.fetchAndCacheAll], so this
/// always completes — success or failure — allowing the screen to fall back
/// to whatever is already cached in Drift.
@Riverpod(keepAlive: true)
Future<void> kgSync(Ref ref) async {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  if (userId.isEmpty) return;
  await ref.read(kgRepositoryProvider).fetchAndCacheAll(userId);
}

/// Watches all concepts from Drift as a stream (keepAlive for related-shorts).
@Riverpod(keepAlive: true)
Stream<List<ConceptEntity>> allConcepts(Ref ref) {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  return ref.watch(kgRepositoryProvider).watchAllConcepts(userId);
}

/// Watches all relationships from Drift as a stream (keepAlive for related-shorts).
@Riverpod(keepAlive: true)
Stream<List<RelationshipEntity>> allRelationships(Ref ref) {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  return ref.watch(kgRepositoryProvider).watchAllRelationships(userId);
}

/// Builds graph nodes with status information.
///
/// Awaits [kgSyncProvider] first, so the screen shows its loading shimmer
/// for the full duration of the API fetch rather than briefly flashing an
/// empty state while the network call is in progress.
/// On subsequent visits within the same session [kgSync] is already
/// resolved (keepAlive), so this reads from Drift instantly.
@riverpod
Future<List<GraphNode>> graphNodes(Ref ref) async {
  await ref.watch(kgSyncProvider.future);
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  return ref.read(kgRepositoryProvider).buildGraphNodes(userId);
}
