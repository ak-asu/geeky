import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/storage_keys.dart';
import '../core/providers/shared_preferences_provider.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/signup_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/notes/domain/note_entity.dart';
import '../features/notes/presentation/screens/create_note_screen.dart';
import '../features/notes/presentation/screens/note_detail_screen.dart';
import '../features/notes/presentation/screens/notes_list_screen.dart';
import '../features/notes/presentation/screens/upload_media_screen.dart';
import '../features/onboarding/presentation/screens/feature_showcase_screen.dart';
import '../features/search/presentation/screens/search_screen.dart';
import '../features/rag_query/presentation/screens/rag_query_screen.dart';
import '../features/analytics/presentation/screens/analytics_dashboard_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/profile/presentation/screens/edit_profile_screen.dart';
import '../features/onboarding/presentation/screens/interest_selection_screen.dart';
import '../features/knowledge_graph/presentation/screens/knowledge_graph_screen.dart';
import '../features/modules/domain/module_entity.dart';
import '../features/modules/presentation/screens/create_module_screen.dart';
import '../features/modules/presentation/screens/module_detail_screen.dart';
import '../features/modules/presentation/screens/modules_list_screen.dart';
import '../features/quiz/presentation/screens/quiz_screen.dart';
import '../features/quiz/presentation/screens/spaced_review_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/shorts/presentation/screens/shorts_feed_screen.dart';
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
              child: const SearchScreen(),
              transitionsBuilder: _fadeTransition,
            ),
          ),
        ],
      ),

      // --- Auth ---
      GoRoute(
        path: '/${RouteNames.login}',
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/${RouteNames.signup}',
        name: RouteNames.signup,
        builder: (context, state) => const SignupScreen(),
      ),

      // --- Onboarding ---
      GoRoute(
        path: '/${RouteNames.onboarding}',
        name: RouteNames.onboarding,
        builder: (context, state) => const FeatureShowcaseScreen(),
      ),
      GoRoute(
        path: '/${RouteNames.interestSelection}',
        name: RouteNames.interestSelection,
        builder: (context, state) => const InterestSelectionScreen(),
      ),

      // --- Notes ---
      GoRoute(
        path: '/${RouteNames.notesList}',
        name: RouteNames.notesList,
        builder: (context, state) => const NotesListScreen(),
      ),
      GoRoute(
        path: '/${RouteNames.noteDetail}',
        name: RouteNames.noteDetail,
        builder: (context, state) {
          final note = state.extra as NoteEntity?;
          if (note == null) {
            return const _PlaceholderScreen('Note not found');
          }
          return NoteDetailScreen(note: note);
        },
      ),
      GoRoute(
        path: '/${RouteNames.createNote}',
        name: RouteNames.createNote,
        builder: (context, state) => const CreateNoteScreen(),
      ),
      GoRoute(
        path: '/${RouteNames.uploadMedia}',
        name: RouteNames.uploadMedia,
        builder: (context, state) => const UploadMediaScreen(),
      ),

      // --- Shorts (module-scoped or filtered view) ---
      GoRoute(
        path: '/${RouteNames.shortsFeed}',
        name: RouteNames.shortsFeed,
        builder: (context, state) {
          final params = state.extra as ShortsFeedParams?;
          return Scaffold(
            appBar: AppBar(
              elevation: 0,
              scrolledUnderElevation: 0,
              title: params?.title != null
                  ? Text(
                      params!.title!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
            body: ShortsFeedScreen(
              filterShortIds: params?.filterShortIds,
              initialIndex: params?.initialIndex ?? 0,
            ),
          );
        },
      ),
      // --- Modules ---
      GoRoute(
        path: '/${RouteNames.modulesList}',
        name: RouteNames.modulesList,
        builder: (context, state) => const ModulesListScreen(),
      ),
      GoRoute(
        path: '/${RouteNames.moduleDetail}',
        name: RouteNames.moduleDetail,
        builder: (context, state) {
          final module = state.extra as ModuleEntity?;
          if (module == null) {
            return const _PlaceholderScreen('Module not found');
          }
          return ModuleDetailScreen(module: module);
        },
      ),
      GoRoute(
        path: '/${RouteNames.createModule}',
        name: RouteNames.createModule,
        builder: (context, state) => const CreateModuleScreen(),
      ),

      // --- Knowledge Graph (premium) ---
      GoRoute(
        path: '/${RouteNames.knowledgeGraph}',
        name: RouteNames.knowledgeGraph,
        builder: (context, state) => const KnowledgeGraphScreen(),
      ),

      // --- Quiz ---
      GoRoute(
        path: '/${RouteNames.quiz}',
        name: RouteNames.quiz,
        builder: (context, state) => const QuizScreen(),
      ),
      GoRoute(
        path: '/${RouteNames.spacedReview}',
        name: RouteNames.spacedReview,
        builder: (context, state) => const SpacedReviewScreen(),
      ),

      // --- RAG (premium) ---
      GoRoute(
        path: '/${RouteNames.ragQuery}',
        name: RouteNames.ragQuery,
        builder: (context, state) => const RagQueryScreen(),
      ),

      // --- Analytics (premium) ---
      GoRoute(
        path: '/${RouteNames.analytics}',
        name: RouteNames.analytics,
        builder: (context, state) => const AnalyticsDashboardScreen(),
      ),

      // --- Profile ---
      GoRoute(
        path: '/${RouteNames.profile}',
        name: RouteNames.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/${RouteNames.editProfile}',
        name: RouteNames.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),

      // --- Settings ---
      GoRoute(
        path: '/${RouteNames.settings}',
        name: RouteNames.settings,
        builder: (context, state) => const SettingsScreen(),
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
