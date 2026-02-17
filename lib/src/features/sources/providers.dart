import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/api_service.dart';
import '../../core/providers/database_provider.dart';
import 'data/sources_repository.dart';
import 'domain/content_source_entity.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
SourcesRepository sourcesRepository(Ref ref) {
  return SourcesRepository(
    ref.read(appDatabaseProvider),
    ref.read(apiServiceProvider),
  );
}

@riverpod
Stream<List<ContentSourceEntity>> allSources(Ref ref) {
  return ref.watch(sourcesRepositoryProvider).watchAllSources();
}
