import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'firebase_provider.g.dart';

@Riverpod(keepAlive: true)
FirebaseAuth firebaseAuth(Ref ref) => FirebaseAuth.instance;

/// Reactive stream of Firebase auth state changes.
@riverpod
Stream<User?> firebaseAuthState(Ref ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
}
