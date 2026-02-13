import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers/shared_preferences_provider.dart';
import 'data/auth_repository.dart';
import 'domain/user_entity.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepository(ref.read(sharedPreferencesProvider));
}

@Riverpod(keepAlive: true)
class Auth extends _$Auth {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  UserEntity? build() => _repo.currentUser;

  Future<void> login({required String email, required String password}) async {
    final user = await _repo.login(email: email, password: password);
    state = user;
  }

  Future<void> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    final user = await _repo.signup(
      name: name,
      email: email,
      password: password,
    );
    state = user;
  }

  Future<void> logout() async {
    await _repo.logout();
    state = null;
  }

  Future<void> updateUser(UserEntity user) async {
    await _repo.updateUser(user);
    state = user;
  }
}

@riverpod
UserEntity? currentUser(Ref ref) {
  return ref.watch(authProvider);
}

@riverpod
bool isLoggedIn(Ref ref) {
  return ref.watch(authProvider) != null;
}
