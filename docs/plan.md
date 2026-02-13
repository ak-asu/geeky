# Geeky Flutter Frontend — Implementation Plan

## Context
Geeky is an AI-driven educational platform transforming multimedia notes into bite-sized learning articles ("Shorts"). The Flutter project is a blank scaffold (only `main.dart` boilerplate). This plan builds the complete frontend with mock data, enabling full UX testing without a backend. The codebase uses feature-first architecture with Riverpod 3.0 codegen, Drift for local DB, GoRouter for navigation, and flex_color_scheme for theming.

## Design Decisions Summary
| Decision | Choice |
|----------|--------|
| Theme | True dual (light + dark, both first-class) via flex_color_scheme |
| Visual tone | Refined minimal + bold typography, sophisticated not childish |
| Accent | Teal/Cyan (#00BFA5) |
| Font | Plus Jakarta Sans (geometric sans, one family) |
| Feed | Horizontal PageView swipe (like Stories). Content scrolls vertically within cards. Swipe LEFT = previous, RIGHT = next (`reverse: true`) |
| Navigation | Feed-centric + slide drawer (icon-triggered only, NOT swipe). No bottom nav bar. App bar auto-hides on scroll |
| Card density | Content-first reader mode (topic tag, title, Markdown body, side rail) |
| Actions | Side action rail: 2 visible (Done + Bookmark), expand upward for more. Fades to 40% after 3s inactivity |
| Drawer | Grouped: LEARN (Modules, Graph, Quiz/Review), MANAGE (Notes, Sources, Bookmarks), YOU (Analytics, Settings) |
| Free/Paid | No login gate. Free = Note feed + client-side. Paid = Shorts + full features. PremiumGate widget + isPremium provider |
| Onboarding | Progressive: welcome + interests at start, rest contextually later |
| Paywall | Bottom sheet with feature preview + pricing |
| Loading | Shimmer skeletons |
| KG visual | Hierarchical tree layout + force-directed physics (draggable, zoomable, like NotebookLM mind map) |
| Motion | Subtle + purposeful (page transitions, card entrance, button scale) |
| RAG | Search-with-answers (not chat) |
| Empty states | Illustrated icon + CTA |
| Spacing | 8pt grid (4pt half-step available) |
| Quiz | Flashcard flip (tap to reveal, self-grade: Again/Hard/Good/Easy) |
| Search | Full-screen overlay from top bar |
| Errors | Snackbar + retry for minor, inline error widget for critical |
| Orientation | Portrait-only |
| Mock backend | Local JSON fixtures seeded into Drift at first launch |

---

## Complete `lib/` Folder Structure

```
lib/
├── main.dart
├── app.dart                              # GeekyApp: MaterialApp.router with theme switching
├── bootstrap.dart                        # Init: Drift, SharedPrefs, mock data seeding
└── src/
    ├── core/
    │   ├── constants/
    │   │   ├── app_constants.dart         # App name, version, FreeTierLimits
    │   │   ├── api_constants.dart         # Base URLs (mock)
    │   │   └── storage_keys.dart          # SharedPreferences keys
    │   ├── errors/
    │   │   ├── failures.dart              # Sealed: ServerFailure, CacheFailure, NetworkFailure
    │   │   ├── exceptions.dart            # AppException, PremiumRequiredException
    │   │   └── error_handler.dart         # showSnackBar / inline error helper
    │   ├── extensions/
    │   │   ├── context_extensions.dart    # theme, textTheme, colorScheme, showSnackBar
    │   │   ├── string_extensions.dart     # capitalize, truncate, initials
    │   │   └── datetime_extensions.dart   # timeAgo, isToday, formatDate
    │   ├── theme/
    │   │   ├── app_theme.dart             # FlexColorScheme light + dark ThemeData
    │   │   ├── app_colors.dart            # Teal palette + surface variants
    │   │   ├── app_typography.dart        # Plus Jakarta Sans text styles
    │   │   └── app_spacing.dart           # 8pt grid: s4..s64 + EdgeInsets helpers
    │   ├── utils/
    │   │   ├── debouncer.dart
    │   │   └── validators.dart
    │   └── widgets/
    │       ├── geeky_scaffold.dart        # Shell: auto-hide app bar + drawer + profile avatar
    │       ├── geeky_drawer.dart          # Grouped nav drawer
    │       ├── horizontal_card_feed.dart  # Generic PageView<T> swipe
    │       ├── side_action_rail.dart      # 2 visible + expandable, fading
    │       ├── auto_hide_app_bar.dart     # SliverAppBar float/snap wrapper
    │       ├── premium_gate.dart          # Free/paid widget gating
    │       ├── paywall_sheet.dart         # Bottom sheet paywall
    │       ├── locked_feature_card.dart   # Dimmed card with lock
    │       ├── geeky_shimmer.dart         # Shimmer skeleton factories
    │       ├── geeky_error_widget.dart    # Inline error + retry
    │       ├── geeky_empty_state.dart     # Icon + text + CTA
    │       ├── connectivity_banner.dart   # Offline banner
    │       ├── markdown_renderer.dart     # Theme-aware markdown_widget wrapper
    │       ├── animated_scale_button.dart # Micro-interaction on tap
    │       └── topic_chip.dart            # Styled topic chip
    ├── routing/
    │   ├── app_router.dart                # GoRouter: all routes + auth redirect
    │   ├── route_names.dart               # Named route constants
    │   └── premium_guard.dart             # Premium route interception
    ├── services/
    │   └── local/
    │       ├── database.dart              # @DriftDatabase definition
    │       ├── tables/                    # 10 Drift table definitions
    │       │   ├── cached_shorts.dart
    │       │   ├── cached_notes.dart
    │       │   ├── cached_modules.dart
    │       │   ├── cached_concepts.dart
    │       │   ├── cached_relationships.dart
    │       │   ├── cached_bookmarks.dart
    │       │   ├── cached_quiz_cards.dart
    │       │   ├── pending_interactions.dart
    │       │   ├── note_feed_state_table.dart
    │       │   └── user_preferences_table.dart
    │       └── daos/                      # 7 DAOs
    │           ├── shorts_dao.dart
    │           ├── notes_dao.dart
    │           ├── modules_dao.dart
    │           ├── sync_dao.dart
    │           ├── note_feed_dao.dart
    │           ├── bookmarks_dao.dart
    │           └── quiz_dao.dart
    └── features/                          # 17 feature modules
        ├── auth/                          # Login, Signup, ForgotPassword
        ├── onboarding/                    # FeatureShowcase, InterestSelection
        ├── home/                          # Shell: GeekyScaffold + AdaptiveFeed
        ├── shorts/                        # ShortsFeed (premium), ShortDetail
        ├── notes/                         # NoteFeed (free), NotesList, CreateNote, Upload
        ├── modules/                       # ModulesList, ModuleDetail, CreateModule
        ├── knowledge_graph/               # Graph visualization (premium)
        ├── search/                        # Search overlay
        ├── rag_query/                     # Search-with-answers (premium)
        ├── quiz/                          # Flashcard quiz, SpacedReview, Results
        ├── analytics/                     # Dashboard, Achievements
        ├── profile/                       # Profile, EditProfile
        ├── settings/                      # Settings, DataManagement
        ├── sources/                       # SourcesList, AddSource, SourceDetail
        ├── bookmarks/                     # BookmarksList
        ├── notifications/                 # NotificationsList
        ├── subscription/                  # SubscriptionScreen
        ├── store/                         # ModuleStore, StoreModuleDetail
        └── offline/                       # SyncRepository, OfflineQueue
```

Each feature folder follows: `data/` (repository + DTOs) → `domain/` (Freezed entities) → `presentation/` (screens + widgets) → `providers.dart`

---

## Phase 1: Foundation & App Shell

**Goal**: Complete app skeleton. After this: app launches, shows splash → mock login → home with empty feed, working drawer, theme switching, shimmer loading.

### Steps

**1.1 — Project Setup**
- Update `pubspec.yaml` with all dependencies (riverpod, go_router, drift, freezed, flex_color_scheme, flutter_animate, shimmer, fl_chart, graphview, markdown_widget, google_fonts, shared_preferences, uuid, etc.)
- Add `build.yaml` for freezed/json_serializable config
- Tighten `analysis_options.yaml` (strict-casts, prefer_const_constructors, etc.)
- Run `flutter pub get`

**1.2 — Core Constants, Errors, Extensions**
- `app_constants.dart`: App name, FreeTierLimits (maxSources: 3, maxStoreModules: 3)
- `storage_keys.dart`: All SharedPreferences key strings
- `failures.dart`: Sealed failure class (Server, Cache, Network, Auth)
- `exceptions.dart`: AppException, PremiumRequiredException
- `error_handler.dart`: Global error → SnackBar helper
- All extension files (context, string, datetime)
- `debouncer.dart`, `validators.dart`

**1.3 — Theme System**
- `app_colors.dart`: Teal primary (#00BFA5), surface variants for light/dark
- `app_typography.dart`: Plus Jakarta Sans, TextTheme with display/headline/body/label styles
- `app_spacing.dart`: 8pt grid constants (s4, s8, s12, s16, s24, s32, s48, s64) + EdgeInsets
- `app_theme.dart`: `AppTheme.light()` + `AppTheme.dark()` using FlexThemeData with FlexSchemeColor, card radius 16, input radius 12

**1.4 — Drift Database**
- Create all 10 table definitions in `services/local/tables/`
- Create all 7 DAOs in `services/local/daos/`
- Create `database.dart` with @DriftDatabase annotation
- Run `dart run build_runner build --delete-conflicting-outputs`

**1.5 — Core Providers**
- `appDatabaseProvider` (keepAlive): AppDatabase singleton
- `sharedPreferencesProvider` (keepAlive): SharedPreferences instance
- `connectivityProvider`: Stream<bool> from connectivity_plus

**1.6 — Shared Widgets** (all 15 widgets listed in folder structure)
- `geeky_scaffold.dart`: Scaffold with SliverAppBar (auto-hide, drawer icon left, avatar right)
- `geeky_drawer.dart`: Grouped sections with avatar header
- `horizontal_card_feed.dart`: Generic `PageView.builder<T>` with `reverse: true`
- `side_action_rail.dart`: 2 visible + expand chevron, 3s fade timer
- `premium_gate.dart` / `paywall_sheet.dart` / `locked_feature_card.dart`
- `geeky_shimmer.dart` / `geeky_error_widget.dart` / `geeky_empty_state.dart`
- `markdown_renderer.dart`: markdown_widget with theme-aware styles

**1.7 — Settings Providers** (just providers, full UI in Phase 5)
- `ThemeModeNotifier` (keepAlive): light/dark/system, persisted to SharedPrefs
- `FontSizeNotifier` (keepAlive): small/medium/large, persisted

**1.8 — Subscription Provider** (mock)
- `SubscriptionNotifier` (keepAlive): returns free tier by default
- `isPremiumProvider`: computed bool
- `togglePremium()` method for dev testing

**1.9 — Routing**
- `route_names.dart`: All 30+ route name constants
- `app_router.dart`: Full GoRouter config (auth redirect, all routes)
- `premium_guard.dart`: Redirect logic for premium-only routes

**1.10 — App Entry Point**
- `bootstrap.dart`: Init Drift + SharedPrefs + seed mock data on first launch
- `app.dart`: MaterialApp.router with theme/darkTheme/themeMode from providers
- `main.dart`: Calls bootstrap, runs ProviderScope + GeekyApp

**1.11 — Home Screen Shell**
- `home_screen.dart`: GeekyScaffold + drawer + AdaptiveFeedScreen body
- `adaptive_feed_screen.dart`: PremiumGate → ShortsFeedScreen (paid) or NoteFeedScreen (free)

**1.12 — Mock Data Fixtures**
- Create JSON fixtures in `assets/mock/`: shorts (25), modules (5), notes (15), concepts (30), relationships (50), quiz data, user profile, store modules (5), achievements (10)
- Topics: AI, Web Dev, Data Science, Mathematics, Cognitive Psychology
- `MockDataService`: Reads JSON, inserts into Drift on first launch
- Update `pubspec.yaml` assets section

---

## Phase 2: Core Features (Feed + Notes + Auth)

**Goal**: Primary UX. User can: mock login → minimal onboarding → swipe through Note feed cards → interact (done/skip/bookmark) → navigate to notes list → create text notes.

### Steps

**2.1 — All Freezed Domain Models** (16 entity groups)
- UserEntity, ShortEntity, NoteEntity, ModuleEntity, ConceptEntity, RelationshipEntity, GraphNode, QuizEntity, QuestionEntity, FSRSCardState, ChatMessage, RagResponse, LearningStreak, TopicProgress, Achievement, ContentSourceEntity, NotificationEntity, StoreModuleEntity, NoteFeedState
- Run `build_runner build` after all models created

**2.2 — DTO Converters** (Drift row ↔ Freezed entity)
- `ShortDto`, `NoteDto`, `ModuleDto` etc. — static `fromRow()` and `toCompanion()` methods

**2.3 — Auth Feature** (mock)
- `auth_repository.dart`: SharedPrefs login state, creates mock user
- `providers.dart`: authNotifier (login/logout), currentUser, isLoggedIn
- `login_screen.dart`: Email + password fields + "Sign In" (any input works)
- `signup_screen.dart`: Name + email + password
- `social_login_button.dart`: Google icon (non-functional placeholder)

**2.4 — Onboarding** (progressive)
- `onboarding_repository.dart`: SharedPrefs for completion state + interests
- `feature_showcase_screen.dart`: 3-page PageView intro
- `interest_selection_screen.dart`: Searchable multi-select topic chips, "Continue" saves

**2.5 — Note Feed** (free tier core)
- `notes_repository.dart`: Drift CRUD
- `note_feed_scorer.dart`: Client-side scoring (recency, read status, skip penalty, topic diversity, time-of-day context)
- `note_feed_screen.dart`: HorizontalCardFeed<NoteEntity>
- `note_card.dart`: Full-screen content-first card with side action rail

**2.6 — Notes Management**
- `notes_list_screen.dart`: All notes grid
- `note_detail_screen.dart`: Full note view
- `create_note_screen.dart`: Text input + save to Drift
- `upload_media_screen.dart`: file_picker → store locally

**2.7 — Interaction Tracking**
- `engagement_tracker.dart`: Stopwatch + scroll depth + side rail fade timer
- InteractionNotifier writes to PendingInteractions table

---

## Phase 3: Learning Features (Shorts + Modules + Quiz + Graph)

**Goal**: Premium tier. Premium toggle shows Shorts feed, modules with progress, KG visualization, flashcard quiz, spaced review.

### Steps

**3.1 — Shorts Feed** (premium)
- `shorts_repository.dart`: Drift CRUD
- `shorts_feed_screen.dart`: HorizontalCardFeed<ShortEntity>
- `short_card.dart`: Content-first with Markdown rendering
- `short_action_rail.dart`: Done, Bookmark + expand (Share, Dive Deeper, Go Up, Related, Feedback, TTS)
- `navigation_options.dart`: KG navigation chips
- `exploration_prompts_list.dart`: Expandable follow-up questions

**3.2 — AdaptiveFeed update**: Wire PremiumGate to switch Note ↔ Shorts feed

**3.3 — Modules**
- `modules_list_screen.dart`: Grid of module cards with progress
- `module_detail_screen.dart`: Module info + shorts list with checkmarks
- `create_module_screen.dart`: Name, description, topic select
- `module_card.dart`, `module_progress_bar.dart`

**3.4 — Knowledge Graph** (premium)
- `kg_repository.dart`: Reads concepts + relationships from Drift
- `knowledge_graph_screen.dart`: Full-screen graph
- `graph_visualization.dart`: graphview with BuchheimWalker tree layout, wrapped in InteractiveViewer for zoom/pan
- `graph_node_widget.dart`: Colored circles by status (mastered=green, in_progress=teal, unread=grey, locked=dark)
- `graph_controls.dart`: Zoom buttons, filter dropdown

**3.5 — Quiz** (flashcard)
- `quiz_screen.dart`: Flashcard flip (AnimatedSwitcher front/back)
- `flashcard_widget.dart`: Question front, answer back, tap to flip
- `self_grade_buttons.dart`: Again / Hard / Good / Easy → simplified FSRS scheduling
- `quiz_result_screen.dart`: Score + per-concept breakdown
- `spaced_review_screen.dart`: Due cards from FSRS scheduling

---

## Phase 4: Discovery & Intelligence (Search + RAG + Analytics)

**Goal**: Search overlay, RAG answers, analytics dashboard, profile.

### Steps

**4.1 — Search** (overlay)
- `search_screen.dart`: Full-screen, auto-focused TextField, recent searches, results
- `search_filters.dart`: Horizontal chips (topic, difficulty, read/unread)
- Mock: substring match on Short title/topics in Drift

**4.2 — RAG Query** (search-with-answers, premium)
- `rag_query_screen.dart`: Search bar + answer card + citations + follow-ups
- `answer_card.dart`: Markdown answer with inline citation chips
- Mock: concatenates relevant Short summaries as "answer"

**4.3 — Analytics**
- `analytics_dashboard_screen.dart`: Streak widget + stats summary + weekly bar chart (fl_chart) + topic progress bars
- `achievements_screen.dart`: Badge grid (locked = greyed)
- `streak_widget.dart`, `stats_summary.dart`, `topic_progress_chart.dart`, `engagement_chart.dart`

**4.4 — Profile**
- `profile_screen.dart`: Avatar, name, expertise radar chart (fl_chart RadarChart)
- `edit_profile_screen.dart`: Edit interests, goals, learning mode

---

## Phase 5: Polish & Integration

**Goal**: Remaining features, animation polish, all drawer links working.

### Steps

**5.1 — Bookmarks**: Bookmarks list screen, bookmark_card with remove action
**5.2 — Sources**: Sources list, add source (URL input + predefined grid), source detail with health badge. Free tier: 3 source limit
**5.3 — Settings UI**: Theme selector, font size slider, TTS toggle, notifications, data management
**5.4 — Module Store**: Store browse grid, detail preview, download button. Free tier: 3 download limit
**5.5 — Notifications** (mock): Mock notification list with read/unread styling
**5.6 — Subscription UI**: Plan comparison, pricing cards, mock upgrade toggle
**5.7 — Animation polish**: Custom GoRouter page transitions, flutter_animate list entrance, shimmer/error/empty state audit across all screens, side rail fade timer, connectivity banner
**5.8 — Offline wiring**: Sync repository, offline queue flush on reconnect, pending sync count stream

---

## Key Patterns

**Repository Pattern**: Every feature's `data/` has a repository returning Freezed entities (never Drift rows). Future swap to Firestore only changes the repository implementation.

**AsyncValue handling**: Every screen uses `asyncValue.when(data: ..., loading: GeekyShimmer, error: GeekyErrorWidget)`.

**Riverpod codegen**: All providers use `@riverpod` annotations. One `providers.dart` per feature. KeepAlive for singletons (DB, auth, theme, subscription).

**Const constructors**: Every widget that can be const, is const. All spacing/color/typography constants are static const.

**Resource disposal**: `ref.onDispose()` cleans up timers, controllers, subscriptions.

---

## Free/Paid Gating Architecture

Three layers:
1. **`PremiumGate` widget**: Wraps premium UI → shows child (premium) or fallback/locked card (free)
2. **`isPremiumProvider`**: Single source of truth computed from SubscriptionNotifier
3. **Route-level `premiumGuard`**: GoRouter redirect for entirely premium routes

Free tier limits enforced via `FreeTierLimits` constants checked in repository methods.

---

## Verification Plan

After each phase:
1. **Phase 1**: App launches → shows splash → navigates to login → home screen renders with drawer, theme toggle works in settings, shimmer shows during loading
2. **Phase 2**: Login → onboarding (interests) → note feed with swipeable cards → done/skip/bookmark work → notes list shows all notes → create text note works
3. **Phase 3**: Toggle premium → shorts feed appears → modules list with progress → KG tree visualization renders → flashcard quiz works with self-grading
4. **Phase 4**: Search overlay finds shorts by keyword → RAG query shows mock answer with citations → analytics dashboard shows streak + charts → profile shows radar chart
5. **Phase 5**: All drawer links work → bookmarks/sources/settings/store/notifications all render → transitions are smooth → offline banner appears when disconnected

**Test commands**: `flutter run` on device/emulator after each phase. `flutter analyze` for lint checks. `dart run build_runner build` after model changes.
