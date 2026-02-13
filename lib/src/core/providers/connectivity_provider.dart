import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_provider.g.dart';

@riverpod
Stream<bool> connectivity(Ref ref) {
  return Connectivity().onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
}

@riverpod
bool isOffline(Ref ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.when(
    data: (connected) => !connected,
    loading: () => false,
    error: (_, _) => true,
  );
}
