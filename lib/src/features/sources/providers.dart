import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'data/sources_repository.dart';
import 'domain/content_source_entity.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
SourcesRepository sourcesRepository(Ref ref) {
  final repo = SourcesRepository();
  ref.onDispose(repo.dispose);
  return repo;
}

@riverpod
Stream<List<ContentSourceEntity>> allSources(Ref ref) {
  return ref.watch(sourcesRepositoryProvider).watchAllSources();
}
