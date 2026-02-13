import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/storage_keys.dart';
import '../domain/user_entity.dart';

class AuthRepository {
  AuthRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _uuid = Uuid();

  bool get isLoggedIn => _prefs.getBool(StorageKeys.isLoggedIn) ?? false;

  UserEntity? get currentUser {
    final json = _prefs.getString(StorageKeys.currentUserJson);
    if (json == null) return null;
    return UserEntity.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<UserEntity> login({
    required String email,
    required String password,
  }) async {
    // Mock: accept any credentials, return existing or create user
    final existing = currentUser;
    if (existing != null && existing.email == email) {
      await _prefs.setBool(StorageKeys.isLoggedIn, true);
      return existing;
    }

    final user = UserEntity(
      id: _uuid.v4(),
      name: _nameFromEmail(email),
      email: email,
      joinedAt: DateTime.now(),
    );

    await _persistUser(user);
    return user;
  }

  Future<UserEntity> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    final user = UserEntity(
      id: _uuid.v4(),
      name: name,
      email: email,
      joinedAt: DateTime.now(),
    );

    await _persistUser(user);
    return user;
  }

  Future<void> logout() async {
    await _prefs.setBool(StorageKeys.isLoggedIn, false);
    await _prefs.remove(StorageKeys.currentUserId);
    await _prefs.remove(StorageKeys.currentUserJson);
  }

  Future<void> updateUser(UserEntity user) async {
    await _prefs.setString(
      StorageKeys.currentUserJson,
      jsonEncode(user.toJson()),
    );
  }

  Future<void> _persistUser(UserEntity user) async {
    await _prefs.setBool(StorageKeys.isLoggedIn, true);
    await _prefs.setString(StorageKeys.currentUserId, user.id);
    await _prefs.setString(
      StorageKeys.currentUserJson,
      jsonEncode(user.toJson()),
    );
  }

  String _nameFromEmail(String email) {
    final local = email.split('@').first;
    return local
        .replaceAll(RegExp(r'[._-]'), ' ')
        .split(' ')
        .map(
          (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '',
        )
        .join(' ')
        .trim();
  }
}
