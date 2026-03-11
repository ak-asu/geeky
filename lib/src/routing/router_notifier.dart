import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/storage_keys.dart';
import '../features/auth/providers.dart';
import 'route_names.dart';

part 'router_notifier.g.dart';

/// Bridges Riverpod auth state to GoRouter's [refreshListenable].
///
/// GoRouter subscribes to this notifier via [addListener]. When
/// [isLoggedInProvider] changes (login / logout / token expiry), the stored
/// listener is called — GoRouter re-evaluates its redirect callback and
/// navigates the user to the correct screen automatically without any manual
/// navigation calls.
@Riverpod(keepAlive: true)
class RouterNotifier extends _$RouterNotifier implements Listenable {
  VoidCallback? _routerListener;

  @override
  bool build() {
    // Listen for auth changes. When isLoggedInProvider changes, update state
    // and ping GoRouter to re-run its redirect immediately.
    ref.listen<bool>(isLoggedInProvider, (_, loggedIn) {
      state = loggedIn;
      _routerListener?.call();
    });
    return ref.read(isLoggedInProvider);
  }

  // ── Listenable ────────────────────────────────────────────────────────────

  @override
  void addListener(VoidCallback listener) => _routerListener = listener;

  @override
  void removeListener(VoidCallback listener) {
    if (_routerListener == listener) _routerListener = null;
  }

  // ── Redirect logic ────────────────────────────────────────────────────────

  /// Called by GoRouter on every navigation attempt and on each auth change.
  ///
  /// Two separate first-launch concepts are tracked independently:
  ///
  /// **[StorageKeys.showcaseCompleted]** — Has the user seen the feature
  /// showcase (3-slide intro)? Pre-auth, one-time, local-only.
  ///
  /// **[StorageKeys.onboardingCompleted]** — Has the user completed interest
  /// selection? Post-auth, new-user setup, synced to backend.
  ///
  /// Full flow for a brand-new user:
  ///   1. Open app → feature showcase  (pre-auth)
  ///   2. Tap "Get Started" → login / signup
  ///   3. Authenticated → interest selection  (post-auth, first-run)
  ///   4. Save interests → app
  ///
  /// Returning users skip straight to the app. Authenticated users who
  /// navigate to showcase / login / signup are redirected away.
  String? handleRedirect(GoRouterState routerState, SharedPreferences prefs) {
    final path = routerState.matchedLocation;
    final showcaseDone = prefs.getBool(StorageKeys.showcaseCompleted) ?? false;
    final onboardingDone =
        prefs.getBool(StorageKeys.onboardingCompleted) ?? false;
    // Riverpod reactive state — always fresh after any auth change.
    final loggedIn = state;

    // ── Feature showcase (pre-auth, one-time intro) ───────────────────────
    if (path == '/${RouteNames.onboarding}') {
      // Authenticated users have no reason to see the intro.
      if (loggedIn && onboardingDone) return '/';
      if (loggedIn && !onboardingDone) {
        return '/${RouteNames.interestSelection}';
      }
      return null; // unauthenticated: show showcase
    }

    // ── Login / Signup (pre-auth) ─────────────────────────────────────────
    const loginPaths = <String>{
      '/${RouteNames.login}',
      '/${RouteNames.signup}',
    };
    if (loginPaths.contains(path)) {
      if (loggedIn && onboardingDone) return '/';
      if (loggedIn && !onboardingDone) {
        return '/${RouteNames.interestSelection}';
      }
      return null; // unauthenticated: allow
    }

    // ── Interest selection (post-auth — first-run and editing) ────────────
    if (path == '/${RouteNames.interestSelection}') {
      if (!loggedIn) return '/${RouteNames.login}';
      return null; // all authenticated users may access
    }

    // ── Protected app paths ───────────────────────────────────────────────
    if (!loggedIn) {
      // Show intro first if not yet seen; otherwise go straight to login.
      if (!showcaseDone) return '/${RouteNames.onboarding}';
      return '/${RouteNames.login}';
    }
    if (!onboardingDone) return '/${RouteNames.interestSelection}';
    return null; // navigation allowed
  }
}
