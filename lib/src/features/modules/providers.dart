import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers/database_provider.dart';
import 'data/modules_repository.dart';
import 'domain/module_entity.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
ModulesRepository modulesRepository(Ref ref) {
  return ModulesRepository(ref.read(appDatabaseProvider));
}

/// Watches all modules from Drift as a stream.
@riverpod
Stream<List<ModuleEntity>> allModules(Ref ref) {
  return ref.watch(modulesRepositoryProvider).watchAllModules();
}

/// Fetches a single module by ID.
@riverpod
Future<ModuleEntity?> moduleById(Ref ref, String id) {
  return ref.watch(modulesRepositoryProvider).getModuleById(id);
}
