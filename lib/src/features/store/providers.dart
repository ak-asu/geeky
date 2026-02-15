import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers/database_provider.dart';
import 'data/store_repository.dart';
import 'domain/store_module_entity.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
StoreRepository storeRepository(Ref ref) {
  return StoreRepository(ref.read(appDatabaseProvider));
}

@riverpod
Stream<List<StoreModuleEntity>> allStoreModules(Ref ref) {
  return ref.watch(storeRepositoryProvider).watchAllModules();
}
