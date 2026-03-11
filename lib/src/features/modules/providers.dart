import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/api_service.dart';
import '../../core/providers/database_provider.dart';
import '../auth/providers.dart';
import 'data/modules_repository.dart';
import 'domain/module_entity.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
ModulesRepository modulesRepository(Ref ref) {
  return ModulesRepository(
    ref.read(appDatabaseProvider),
    ref.read(apiServiceProvider),
  );
}

/// Watches all modules from Drift as a stream.
@riverpod
Stream<List<ModuleEntity>> allModules(Ref ref) {
  final userId = ref.watch(currentUserProvider)?.id ?? '';
  return ref.watch(modulesRepositoryProvider).watchAllModules(userId);
}

/// Fetches a single module by ID.
@riverpod
Future<ModuleEntity?> moduleById(Ref ref, String id) {
  return ref.watch(modulesRepositoryProvider).getModuleById(id);
}
