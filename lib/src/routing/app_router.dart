import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/storage_keys.dart';
import '../core/providers/shared_preferences_provider.dart';
import '../features/home/presentation/screens/home_screen.dart';
import 'premium_guard.dart';
import 'route_names.dart';

part 'app_router.g.dart';

// Placeholder screens — replaced by real screens as features are built
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final prefs = ref.read(sharedPreferencesProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      // Root redirect (auth / onboarding)
      final rootRedirect = _rootRedirect(prefs, state);
      if (rootRedirect != null) return rootRedirect;

      // Premium guard
      return checkPremiumAccess(ref, state.matchedLocation);
    },
    routes: [
      // --- Home Shell ---
      GoRoute(
        path: '/',
        name: RouteNames.home,
        builder: (context, state) => const HomeScreen(),
        routes: [
          // Search overlay
          GoRoute(
            path: RouteNames.search,
            name: RouteNames.search,
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const _PlaceholderScreen('Search'),
              transitionsBuilder: _fadeTransition,
            ),
          ),
        ],
      ),

      // --- Auth ---
      GoRoute(
        path: '/${RouteNames.login}',
        name: RouteNames.login,
        builder: (context, state) => const _PlaceholderScreen('Login'),
      ),
      GoRoute(
        path: '/${RouteNames.signup}',
        name: RouteNames.signup,
        builder: (context, state) => const _PlaceholderScreen('Sign Up'),
      ),

      // --- Onboarding ---
      GoRoute(
        path: '/${RouteNames.onboarding}',
        name: RouteNames.onboarding,
        builder: (context, state) => const _PlaceholderScreen('Onboarding'),
      ),
      GoRoute(
        path: '/${RouteNames.interestSelection}',
        name: RouteNames.interestSelection,
        builder: (context, state) =>
            const _PlaceholderScreen('Interest Selection'),
      ),

      // --- Notes ---
      GoRoute(
        path: '/${RouteNames.notesList}',
        name: RouteNames.notesList,
        builder: (context, state) => const _PlaceholderScreen('Notes'),
      ),
      GoRoute(
        path: '/${RouteNames.noteDetail}',
        name: RouteNames.noteDetail,
        builder: (context, state) => const _PlaceholderScreen('Note Detail'),
      ),
      GoRoute(
        path: '/${RouteNames.createNote}',
        name: RouteNames.createNote,
        builder: (context, state) => const _PlaceholderScreen('Create Note'),
      ),
      GoRoute(
        path: '/${RouteNames.uploadMedia}',
        name: RouteNames.uploadMedia,
        builder: (context, state) => const _PlaceholderScreen('Upload Media'),
      ),

      // --- Shorts (premium) ---
      GoRoute(
        path: '/${RouteNames.shortDetail}',
        name: RouteNames.shortDetail,
        builder: (context, state) => const _PlaceholderScreen('Short Detail'),
      ),

      // --- Modules ---
      GoRoute(
        path: '/${RouteNames.modulesList}',
        name: RouteNames.modulesList,
        builder: (context, state) => const _PlaceholderScreen('Modules'),
      ),
      GoRoute(
        path: '/${RouteNames.moduleDetail}',
        name: RouteNames.moduleDetail,
        builder: (context, state) => const _PlaceholderScreen('Module Detail'),
      ),
      GoRoute(
        path: '/${RouteNames.createModule}',
        name: RouteNames.createModule,
        builder: (context, state) => const _PlaceholderScreen('Create Module'),
      ),

      // --- Knowledge Graph (premium) ---
      GoRoute(
        path: '/${RouteNames.knowledgeGraph}',
        name: RouteNames.knowledgeGraph,
        builder: (context, state) =>
            const _PlaceholderScreen('Knowledge Graph'),
      ),

      // --- Quiz ---
      GoRoute(
        path: '/${RouteNames.quiz}',
        name: RouteNames.quiz,
        builder: (context, state) => const _PlaceholderScreen('Quiz'),
      ),
      GoRoute(
        path: '/${RouteNames.spacedReview}',
        name: RouteNames.spacedReview,
        builder: (context, state) => const _PlaceholderScreen('Spaced Review'),
      ),

      // --- RAG (premium) ---
      GoRoute(
        path: '/${RouteNames.ragQuery}',
        name: RouteNames.ragQuery,
        builder: (context, state) => const _PlaceholderScreen('Ask a Question'),
      ),

      // --- Analytics (premium) ---
      GoRoute(
        path: '/${RouteNames.analytics}',
        name: RouteNames.analytics,
        builder: (context, state) => const _PlaceholderScreen('Analytics'),
      ),

      // --- Profile ---
      GoRoute(
        path: '/${RouteNames.profile}',
        name: RouteNames.profile,
        builder: (context, state) => const _PlaceholderScreen('Profile'),
      ),
      GoRoute(
        path: '/${RouteNames.editProfile}',
        name: RouteNames.editProfile,
        builder: (context, state) => const _PlaceholderScreen('Edit Profile'),
      ),

      // --- Settings ---
      GoRoute(
        path: '/${RouteNames.settings}',
        name: RouteNames.settings,
        builder: (context, state) => const _PlaceholderScreen('Settings'),
      ),

      // --- Sources ---
      GoRoute(
        path: '/${RouteNames.sourcesList}',
        name: RouteNames.sourcesList,
        builder: (context, state) => const _PlaceholderScreen('Sources'),
      ),

      // --- Bookmarks ---
      GoRoute(
        path: '/${RouteNames.bookmarks}',
        name: RouteNames.bookmarks,
        builder: (context, state) => const _PlaceholderScreen('Bookmarks'),
      ),

      // --- Notifications ---
      GoRoute(
        path: '/${RouteNames.notifications}',
        name: RouteNames.notifications,
        builder: (context, state) => const _PlaceholderScreen('Notifications'),
      ),

      // --- Subscription ---
      GoRoute(
        path: '/${RouteNames.subscription}',
        name: RouteNames.subscription,
        builder: (context, state) => const _PlaceholderScreen('Subscription'),
      ),

      // --- Store ---
      GoRoute(
        path: '/${RouteNames.store}',
        name: RouteNames.store,
        builder: (context, state) => const _PlaceholderScreen('Module Store'),
      ),
    ],
  );
}

/// Root redirect logic: onboarding → login → home
String? _rootRedirect(SharedPreferences prefs, GoRouterState state) {
  final path = state.matchedLocation;
  final onboardingDone =
      prefs.getBool(StorageKeys.onboardingCompleted) ?? false;
  final isLoggedIn = prefs.getBool(StorageKeys.isLoggedIn) ?? false;

  // Allow auth and onboarding routes through
  const authPaths = [
    '/${RouteNames.login}',
    '/${RouteNames.signup}',
    '/${RouteNames.onboarding}',
    '/${RouteNames.interestSelection}',
  ];
  if (authPaths.contains(path)) return null;

  // Not onboarded → send to onboarding
  if (!onboardingDone) return '/${RouteNames.onboarding}';

  // Not logged in → send to login
  if (!isLoggedIn) return '/${RouteNames.login}';

  return null;
}

Widget _fadeTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return FadeTransition(opacity: animation, child: child);
}
