import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../core/providers/shared_preferences_provider.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/signup_screen.dart';
import '../features/bookmarks/presentation/screens/bookmarks_list_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/notes/domain/note_entity.dart';
import '../features/notes/presentation/screens/create_note_screen.dart';
import '../features/notes/presentation/screens/note_detail_screen.dart';
import '../features/notes/presentation/screens/notes_list_screen.dart';
import '../features/notes/presentation/screens/upload_media_screen.dart';
import '../features/notifications/presentation/screens/notifications_list_screen.dart';
import '../features/onboarding/presentation/screens/feature_showcase_screen.dart';
import '../features/onboarding/presentation/screens/interest_selection_screen.dart';
import '../features/search/presentation/screens/search_screen.dart';
import '../features/rag_query/presentation/screens/rag_query_screen.dart';
import '../features/analytics/presentation/screens/analytics_dashboard_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/profile/presentation/screens/edit_profile_screen.dart';
import '../features/knowledge_graph/presentation/screens/knowledge_graph_screen.dart';
import '../features/modules/domain/module_entity.dart';
import '../features/modules/presentation/screens/create_module_screen.dart';
import '../features/modules/presentation/screens/module_detail_screen.dart';
import '../features/modules/presentation/screens/modules_list_screen.dart';
import '../features/modules/providers.dart';
import '../features/quiz/presentation/screens/quiz_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/shorts/presentation/screens/shorts_feed_screen.dart';
import '../features/sources/domain/content_source_entity.dart';
import '../features/sources/presentation/screens/add_source_screen.dart';
import '../features/sources/presentation/screens/source_detail_screen.dart';
import '../features/sources/presentation/screens/sources_list_screen.dart';
import '../features/store/domain/store_module_entity.dart';
import '../features/store/presentation/screens/module_store_screen.dart';
import '../features/notes/presentation/screens/voice_memo_screen.dart';
import '../features/store/presentation/screens/store_module_detail_screen.dart';
import '../features/subscription/presentation/screens/subscription_screen.dart';
import '../core/providers/share_provider.dart';
import 'premium_guard.dart';
import 'route_names.dart';
import 'router_notifier.dart';

part 'app_router.g.dart';

// Fallback screen for missing entities
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
}

/// Loads a [ModuleEntity] by ID and forwards to [ModuleDetailScreen].
///
/// Used by the `/modules/:moduleId` deep-link route so that external URIs
/// (e.g. `geeky://modules/abc123`) open the correct module detail screen
/// rather than the generic modules list.
class _ModuleDeepLinkScreen extends ConsumerWidget {
  const _ModuleDeepLinkScreen({required this.moduleId});

  final String moduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moduleAsync = ref.watch(moduleByIdProvider(moduleId));
    return moduleAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const _NotFoundScreen('Module not found'),
      data: (module) => module != null
          ? ModuleDetailScreen(module: module)
          : const _NotFoundScreen('Module not found'),
    );
  }
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  // ref.read — NOT ref.watch. Watching would rebuild (and recreate) the
  // GoRouter every time auth state changes, resetting the navigation stack.
  // The refreshListenable below is the reactive bridge instead.
  // routerProvider is generated from RouterNotifier (Riverpod drops "Notifier" suffix).
  final notifier = ref.read(routerProvider.notifier);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    // Tells GoRouter to re-run redirect whenever auth state changes.
    refreshListenable: notifier,
    redirect: (context, state) {
      // Auth / onboarding guard (reactive via RouterNotifier).
      final authRedirect = notifier.handleRedirect(state, prefs);
      if (authRedirect != null) return authRedirect;

      // Premium feature guard.
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
        builder: (context, state) => InterestSelectionScreen(
          // extra == true when navigated from profile for editing.
          isEditing: state.extra as bool? ?? false,
        ),
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
            return const _NotFoundScreen('Note not found');
          }
          return NoteDetailScreen(note: note);
        },
      ),
      GoRoute(
        path: '/${RouteNames.createNote}',
        name: RouteNames.createNote,
        builder: (context, state) {
          final share = state.extra as ShareContent?;
          return CreateNoteScreen(initialContent: share?.text);
        },
      ),
      GoRoute(
        path: '/${RouteNames.uploadMedia}',
        name: RouteNames.uploadMedia,
        builder: (context, state) {
          final share = state.extra as ShareContent?;
          return UploadMediaScreen(initialFilePath: share?.filePath);
        },
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
            return const _NotFoundScreen('Module not found');
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
      // --- RAG (premium) ---
      GoRoute(
        path: '/${RouteNames.ragQuery}',
        name: RouteNames.ragQuery,
        builder: (context, state) =>
            RagQueryScreen(initialQuery: state.extra as String?),
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
        pageBuilder: (context, state) =>
            _slidePage(state, const EditProfileScreen()),
      ),

      // --- Settings ---
      GoRoute(
        path: '/${RouteNames.settings}',
        name: RouteNames.settings,
        pageBuilder: (context, state) =>
            _slidePage(state, const SettingsScreen()),
      ),

      // --- Sources ---
      GoRoute(
        path: '/${RouteNames.sourcesList}',
        name: RouteNames.sourcesList,
        builder: (context, state) => const SourcesListScreen(),
      ),
      GoRoute(
        path: '/${RouteNames.addSource}',
        name: RouteNames.addSource,
        pageBuilder: (context, state) =>
            _slidePage(state, const AddSourceScreen()),
      ),
      GoRoute(
        path: '/${RouteNames.sourceDetail}',
        name: RouteNames.sourceDetail,
        pageBuilder: (context, state) {
          final source = state.extra as ContentSourceEntity?;
          if (source == null) {
            return _slidePage(state, const _NotFoundScreen('Source not found'));
          }
          return _slidePage(state, SourceDetailScreen(source: source));
        },
      ),

      // --- Bookmarks ---
      GoRoute(
        path: '/${RouteNames.bookmarks}',
        name: RouteNames.bookmarks,
        builder: (context, state) => const BookmarksListScreen(),
      ),

      // --- Notifications ---
      GoRoute(
        path: '/${RouteNames.notifications}',
        name: RouteNames.notifications,
        builder: (context, state) => const NotificationsListScreen(),
      ),

      // --- Subscription ---
      GoRoute(
        path: '/${RouteNames.subscription}',
        name: RouteNames.subscription,
        pageBuilder: (context, state) =>
            _slidePage(state, const SubscriptionScreen()),
      ),

      // --- Store ---
      GoRoute(
        path: '/${RouteNames.store}',
        name: RouteNames.store,
        builder: (context, state) => const ModuleStoreScreen(),
      ),
      GoRoute(
        path: '/${RouteNames.storeModuleDetail}',
        name: RouteNames.storeModuleDetail,
        pageBuilder: (context, state) {
          final module = state.extra as StoreModuleEntity?;
          if (module == null) {
            return _slidePage(
              state,
              const _NotFoundScreen('Store module not found'),
            );
          }
          return _slidePage(state, StoreModuleDetailScreen(module: module));
        },
      ),

      // --- Voice Memo ---
      GoRoute(
        path: '/${RouteNames.voiceMemo}',
        name: RouteNames.voiceMemo,
        pageBuilder: (context, state) =>
            _slidePage(state, const VoiceMemoScreen()),
      ),

      // --- Deep-link path-param routes (custom URI scheme + App Links) ---
      // geeky://shorts/<id>  or  https://geeky.app/shorts/<id>
      GoRoute(
        path: '/shorts/:shortId',
        name: RouteNames.shortDeepLink,
        builder: (context, state) {
          final shortId = state.pathParameters['shortId'] ?? '';
          return Scaffold(
            appBar: AppBar(elevation: 0, scrolledUnderElevation: 0),
            body: ShortsFeedScreen(filterShortIds: [shortId]),
          );
        },
      ),
      // geeky://modules/<id>  or  https://geeky.app/modules/<id>
      GoRoute(
        path: '/modules/:moduleId',
        name: RouteNames.moduleDeepLink,
        builder: (context, state) {
          final moduleId = state.pathParameters['moduleId'] ?? '';
          return _ModuleDeepLinkScreen(moduleId: moduleId);
        },
      ),
      // geeky://quiz/<id>  or  https://geeky.app/quiz/<id>
      // quizId is reserved for future quiz-session deep links; currently
      // navigates to the spaced-repetition queue (all due cards).
      GoRoute(
        path: '/quiz/:quizId',
        name: RouteNames.quizDeepLink,
        builder: (context, state) => const QuizScreen(),
      ),
    ],
  );
}

Widget _fadeTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return FadeTransition(opacity: animation, child: child);
}

Widget _slideTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final slideIn = Tween<Offset>(
    begin: const Offset(1, 0),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
  final fadeIn = CurvedAnimation(parent: animation, curve: Curves.easeOut);

  return SlideTransition(
    position: slideIn,
    child: FadeTransition(opacity: fadeIn, child: child),
  );
}

/// Creates a [CustomTransitionPage] with a slide-from-right transition.
CustomTransitionPage<void> _slidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: _slideTransition,
  );
}
