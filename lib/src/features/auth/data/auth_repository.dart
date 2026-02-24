import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/storage_keys.dart';
import '../domain/user_entity.dart';

class AuthRepository {
  AuthRepository(this._auth, this._prefs) {
    // A standalone Dio instance without auth interceptors is used for profile
    // sync to avoid a circular dependency:
    // authRepository → apiClient → AuthInterceptor → authRepository.
    _rawDio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
      ),
    );
  }

  final FirebaseAuth _auth;
  final SharedPreferences _prefs;
  late final Dio _rawDio;

  /// Cached ID token to avoid repeated async calls.
  String? _cachedToken;
  DateTime? _tokenExpiry;

  /// Flag to track if GoogleSignIn has been initialized.
  bool _googleSignInInitialized = false;

  // ---------------------------------------------------------------------------
  // Auth state
  // ---------------------------------------------------------------------------

  bool get isLoggedIn => _auth.currentUser != null;

  UserEntity? get currentUser {
    final fbUser = _auth.currentUser;
    if (fbUser != null) return _mapFirebaseUser(fbUser);

    // Fallback: read from SharedPreferences for fast cold start
    final json = _prefs.getString(StorageKeys.currentUserJson);
    if (json == null) return null;
    return UserEntity.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  /// Returns a valid Firebase ID token for API authorization.
  /// Caches the token and only refreshes when near expiry.
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    // Return cached token if still valid (5-min buffer)
    if (!forceRefresh &&
        _cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(
          _tokenExpiry!.subtract(const Duration(minutes: 5)),
        )) {
      return _cachedToken;
    }

    _cachedToken = await user.getIdToken(forceRefresh);
    // Firebase tokens expire after 1 hour
    _tokenExpiry = DateTime.now().add(const Duration(hours: 1));
    return _cachedToken;
  }

  // ---------------------------------------------------------------------------
  // Email / password
  // ---------------------------------------------------------------------------

  Future<UserEntity> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = _mapFirebaseUser(credential.user!);
    await _cacheUser(user);
    unawaited(_fetchAndCacheUserProfile());
    return user;
  }

  Future<UserEntity> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user!.updateDisplayName(name);
    await credential.user!.reload();

    final user = _mapFirebaseUser(_auth.currentUser!);
    await _cacheUser(user);
    unawaited(_fetchAndCacheUserProfile());
    return user;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  // ---------------------------------------------------------------------------
  // Google Sign-In
  // ---------------------------------------------------------------------------

  /// Ensures GoogleSignIn is initialized before use (v7.x requirement).
  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;

    await GoogleSignIn.instance.initialize(
      // clientId and serverClientId can be configured here if needed,
      // otherwise uses platform defaults from Android/iOS configuration
    );
    _googleSignInInitialized = true;
  }

  Future<UserEntity> signInWithGoogle() async {
    await _ensureGoogleSignInInitialized();

    // Create a completer to bridge stream events to Future return
    final completer = Completer<GoogleSignInAccount>();
    StreamSubscription<GoogleSignInAuthenticationEvent>? subscription;

    try {
      // Listen to authentication events to get the signed-in user
      subscription = GoogleSignIn.instance.authenticationEvents.listen(
        (event) {
          if (event is GoogleSignInAuthenticationEventSignIn) {
            if (!completer.isCompleted) {
              completer.complete(event.user);
            }
          }
        },
        onError: (Object error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );

      // Trigger the authentication flow
      await GoogleSignIn.instance.authenticate();

      // Wait for the user from the event stream
      final googleUser = await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw FirebaseAuthException(
            code: 'google-sign-in-timeout',
            message: 'Google sign-in timed out',
          );
        },
      );

      // Get ID token from authentication (synchronous getter in v7.x)
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      // Get access token from authorization (required for Firebase)
      // Request 'email' scope for basic profile access
      final authorization = await googleUser.authorizationClient
          .authorizationForScopes(['email']);

      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'google-sign-in-failed',
          message: 'Failed to obtain ID token',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: authorization?.accessToken,
        idToken: idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      final user = _mapFirebaseUser(result.user!);
      await _cacheUser(user);
      unawaited(_fetchAndCacheUserProfile());
      return user;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw FirebaseAuthException(
          code: 'google-sign-in-cancelled',
          message: 'Google sign-in was cancelled',
        );
      }
      rethrow;
    } finally {
      await subscription?.cancel();
    }
  }

  // ---------------------------------------------------------------------------
  // Logout
  // ---------------------------------------------------------------------------

  Future<void> logout() async {
    _cachedToken = null;
    _tokenExpiry = null;

    // Disconnect from Google Sign-In (v7.x uses disconnect instead of signOut)
    if (_googleSignInInitialized) {
      try {
        await GoogleSignIn.instance.disconnect();
      } catch (_) {
        // Ignore errors if not signed in
      }
    }

    await _auth.signOut();
    await _prefs.setBool(StorageKeys.isLoggedIn, false);
    await _prefs.remove(StorageKeys.currentUserId);
    await _prefs.remove(StorageKeys.currentUserJson);
  }

  // ---------------------------------------------------------------------------
  // Profile update — local cache + backend sync
  // ---------------------------------------------------------------------------

  Future<void> updateUser(UserEntity user) async {
    await _cacheUser(user);
    // Best-effort backend sync — does not block the UI update
    _patchUserProfile({
      'name': user.name,
      'interests': user.interests,
      'goals': user.goals,
      'expertise_level': user.expertiseLevel,
    }).ignore();
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  UserEntity _mapFirebaseUser(User fbUser) {
    // Read cached profile data for fields not stored in Firebase Auth
    final cachedJson = _prefs.getString(StorageKeys.currentUserJson);
    UserEntity? cached;
    if (cachedJson != null) {
      try {
        cached = UserEntity.fromJson(
          jsonDecode(cachedJson) as Map<String, dynamic>,
        );
      } catch (_) {
        // Ignore malformed cache
      }
    }

    return UserEntity(
      id: fbUser.uid,
      name: fbUser.displayName ?? cached?.name ?? '',
      email: fbUser.email ?? cached?.email ?? '',
      avatarUrl: fbUser.photoURL ?? cached?.avatarUrl,
      interests: cached?.interests ?? const [],
      goals: cached?.goals ?? const [],
      topicFamiliarity: cached?.topicFamiliarity ?? const {},
      expertiseLevel: cached?.expertiseLevel ?? 'beginner',
      joinedAt:
          fbUser.metadata.creationTime ?? cached?.joinedAt ?? DateTime.now(),
    );
  }

  Future<void> _cacheUser(UserEntity user) async {
    await _prefs.setBool(StorageKeys.isLoggedIn, true);
    await _prefs.setString(StorageKeys.currentUserId, user.id);
    await _prefs.setString(
      StorageKeys.currentUserJson,
      jsonEncode(user.toJson()),
    );
  }

  /// Fetches the full user profile from the backend and merges it into the
  /// local cache. Called in the background after sign-in.
  Future<void> _fetchAndCacheUserProfile() async {
    try {
      final token = await getIdToken();
      if (token == null) return;

      final response = await _rawDio.get(
        '${ApiConstants.users}/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final body = response.data;
      final data = body is Map<String, dynamic> && body.containsKey('data')
          ? body['data'] as Map<String, dynamic>?
          : body as Map<String, dynamic>?;
      if (data == null) return;

      final current = currentUser;
      if (current == null) return;

      final enriched = current.copyWith(
        interests:
            (data['interests'] as List<dynamic>?)?.cast<String>() ??
            current.interests,
        goals:
            (data['goals'] as List<dynamic>?)?.cast<String>() ?? current.goals,
        expertiseLevel:
            data['expertiseLevel'] as String? ?? current.expertiseLevel,
      );
      await _cacheUser(enriched);
    } catch (_) {
      // Non-blocking — local cache remains valid on failure
    }
  }

  /// PATCHes user profile fields to the backend. Best-effort, non-blocking.
  Future<void> _patchUserProfile(Map<String, dynamic> fields) async {
    try {
      final token = await getIdToken();
      if (token == null) return;

      await _rawDio.patch(
        '${ApiConstants.users}/me',
        data: fields,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {
      // Non-blocking — local update already applied
    }
  }
}
