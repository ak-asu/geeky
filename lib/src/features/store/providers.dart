import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'data/store_repository.dart';
import 'domain/store_module_entity.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
StoreRepository storeRepository(Ref ref) {
  final repo = StoreRepository();
  ref.onDispose(repo.dispose);
  return repo;
}

@riverpod
Stream<List<StoreModuleEntity>> allStoreModules(Ref ref) {
  return ref.watch(storeRepositoryProvider).watchAllModules();
}
