# Geeky — AI Coding Instructions

## System Overview

Geeky is a Flutter 3.x offline-first educational platform that transforms multimedia notes into bite-sized "Shorts" organized via a Knowledge Graph, with adaptive learning paths, spaced repetition quizzes, and RAG-powered Q&A. The Flutter frontend (this repo) handles all UI and local data; a Python/FastAPI backend (separate repo, not yet built) will handle AI/ML workloads (summarization, embeddings, content processing via Gemini API).

**For Flutter implementation guidance**, refer to `.claude/skills/flutter-expert/SKILL.md`.
**For UI/UX design decisions**, refer to `.claude/skills/frontend-design/SKILL.md`.

## Architecture & Data Flow

**Clean Architecture lite** — feature-first modularity under `lib/src/features/`:

```
feature_name/
├── data/              # Repository impl + DTO (*_dto.dart maps row ↔ entity)
├── domain/            # Freezed entity models (*_entity.dart)
├── presentation/
│   ├── screens/       # Full-page widgets (*_screen.dart)
│   └── widgets/       # Feature-scoped reusable widgets
├── providers.dart     # @riverpod annotated providers
└── providers.g.dart   # Generated
```

**Data flow**: `Widget → Provider → Repository → DAO → Drift Table (SQLite)`

Shared code in `lib/src/core/`: `constants/`, `errors/`, `extensions/`, `providers/`, `theme/`, `utils/`, `widgets/`.

**Exception**: `settings/` has empty `data/` and `domain/` folders — preferences are managed purely through `SharedPreferences` + Riverpod notifiers (no DB persistence needed).

## Features & Premium Gating

19 feature modules: `analytics`, `auth`, `bookmarks`, `home`, `knowledge_graph`, `modules`, `notes`, `notifications`, `offline`, `onboarding`, `profile`, `quiz`, `rag_query`, `search`, `settings`, `shorts`, `sources`, `store`, `subscription`.

**Premium-gated** (route-level via `premiumGuard` + widget-level via `PremiumGate`): `knowledgeGraph`, `ragQuery`, `analytics`, `quiz`, `spacedReview`. Free users see `LockedFeatureCard` fallback or redirect to subscription screen.

**Free tier limits** defined in `AppConstants`: max 3 sources, 3 store modules, 50 notes.

## Services & Infrastructure

### Drift Database (`lib/src/services/local/`)
- **Database**: `AppDatabase` in `database.dart` — 13 tables, 11 DAOs, schema version 4 with incremental migrations
- **Tables**: `lib/src/services/local/tables/` — named `CachedFoos` (plural). Complex types stored as JSON strings in `*Json` columns (e.g., `topicsJson`, `engagementJson`)
- **DAOs**: `lib/src/services/local/daos/` — every DAO provides both `get()` (Future) and `watch()` (Stream) variants. Use `insertOnConflictUpdate` for upserts, `batch` for bulk inserts
- **SQLite file**: `geeky.sqlite` in app documents dir, opened via `NativeDatabase.createInBackground`
- **Testing**: `AppDatabase.forTesting(super.e)` constructor

### Mock Data Seeding
JSON fixtures in `assets/mock/` are batch-inserted into Drift on first launch via `MockDataService.seedIfNeeded()`, guarded by `StorageKeys.mockDataSeeded` SharedPreferences flag. Called in `bootstrap.dart` before app starts. Covers 9 entity types.

### Connectivity & Offline Sync
- `ConnectivityBanner` wraps the app — shows/hides an animated offline banner
- `syncOnReconnect` provider auto-flushes `PendingInteractions` queue when connectivity is restored
- User interactions are queued locally and synced when back online

## State Management — Riverpod 3

All providers use `@riverpod` annotation with code generation. Three patterns:

1. **Singleton service** — `@Riverpod(keepAlive: true)` function returning a repository instance
2. **Reactive stream/future** — `@riverpod` function watching a DAO's `watch*()` method (auto-dispose)
3. **Stateful notifier** — `@Riverpod(keepAlive: true) class FooNotifier extends _$FooNotifier` with methods that mutate `state`

**Infrastructure providers** (`appDatabaseProvider`, `sharedPreferencesProvider`) throw `UnimplementedError` by default and are overridden in `main.dart` via `ProviderScope.overrides` after `bootstrap()` initializes them. This ensures testability.

**Provider composition**: derived providers `ref.watch()` other providers to combine/transform data (e.g., `rankedNoteFeed` merges `allNotes` + `noteFeedState` + scoring).

## Models & Data Mapping

### Freezed 3 Entities (`*_entity.dart`)
- `@freezed abstract class FooEntity with _$FooEntity` — immutable, with `copyWith`, equality, JSON support
- Named parameters only: `required` for mandatory, `@Default(...)` for optionals
- Always include `factory FooEntity.fromJson(Map<String, dynamic> json)`

### DTOs (`*_dto.dart`)
- `abstract final class FooDto` — static-only mapping class (pure namespace, not instantiable)
- `static FooEntity fromRow(CachedFoo row)` — decodes `*Json` columns via `jsonDecode`
- `static CachedFoosCompanion toCompanion(FooEntity e)` — encodes lists/maps via `jsonEncode`

## Routing & Navigation

- **GoRouter** as a `@Riverpod(keepAlive: true)` provider in `app_router.dart`
- **Route names**: `abstract final class RouteNames` with `static const String` fields (kebab-case: `'note-detail'`, `'shorts-feed'`)
- **Entity passing**: via `GoRoute.extra` — always null-check with `_NotFoundScreen` fallback
- **Transitions**: `_fadeTransition` for overlays (search), `_slidePage` for detail screens
- **Guards**: root redirect checks onboarding/auth via SharedPreferences keys; `checkPremiumAccess` redirects free users from premium routes to subscription screen

## Theming & Styling

- **FlexColorScheme** + **Material 3** + **Google Fonts (Plus Jakarta Sans)**
- **Design tokens** — all `abstract final class` pure namespaces:
  - `AppColors`: primary teal (`#00BFA5`), semantic colors (error/success/warning), KG node status colors (mastered/inProgress/unread/locked), light/dark surface pairs
  - `AppSpacing`: 8pt grid (`s4`–`s64`), border radii (`radiusSm`–`radiusFull`), pre-built `EdgeInsets` (`paddingAll16`, `paddingH24`…) and `SizedBox` gaps (`gapV8`, `gapH16`…)
  - `AppTypography`: full `TextTheme` with explicit sizes/weights/heights for all M3 text styles
- **Font scaling**: `FontSizeOption` enum (small=0.9, medium=1.0, large=1.15) applied via `MediaQuery` + `TextScaler.linear()` in `app.dart`
- **Theme mode**: `ThemeModeNotifier` reads/writes `StorageKeys.themeMode` — light/dark/system, immediate reactivity

## Error Handling

- `sealed class Failure` → `ServerFailure`, `CacheFailure`, `NetworkFailure`, `AuthFailure`, `ValidationFailure`
- `AppException` → `PremiumRequiredException`, `DownloadLimitException`, `SourceLimitException`
- `ErrorHandler.showError(context, error)` extracts message from either hierarchy, shows floating `SnackBar`
- `ErrorHandler.showErrorWithRetry(context, error, onRetry)` adds retry action

## Code Practices

### Naming Conventions
- Entities: `*_entity.dart` | DTOs: `*_dto.dart` | Repos: `*s_repository.dart` (plural) | Screens: `*_screen.dart`
- Tables: `CachedFoos` (plural) | DAOs: `FoosDao` | All namespace classes: `abstract final class`

### Linting (`analysis_options.yaml`)
- `strict-casts: true`, `strict-raw-types: true`
- Key rules: `prefer_const_constructors`, `prefer_single_quotes`, `avoid_print`, `prefer_final_locals`, `always_declare_return_types`
- Generated files excluded: `**/*.g.dart`, `**/*.freezed.dart`

### Build & Code Generation
```bash
dart run build_runner build --delete-conflicting-outputs   # Full gen (Freezed, Riverpod, Drift, json_serializable)
dart run build_runner watch --delete-conflicting-outputs   # Watch mode
flutter test                                               # Run tests
flutter build apk --release                                # Release APK
```
`build.yaml`: `json_serializable` uses `field_rename: snake`, `explicit_to_json: true`.

### Context Extensions (`lib/src/core/extensions/`)
- `BuildContext`: `.theme`, `.textTheme`, `.colorScheme`, `.isDark`, `.showSnackBar()`
- `String`: `.capitalized`, `.titleCase`, `.truncate()`, `.initials`
- `DateTime`: `.isToday`, `.timeAgo`, `.formatDate`, `.formatShort`

## Shared Widgets (`lib/src/core/widgets/`)

`GeekyScaffold` (sliver app bar + drawer), `GeekyErrorWidget` (retry, compact/full modes), `GeekyEmptyState` (icon + action), `GeekyShimmer` (factories: `.feedCard()`, `.listItem()`, `.gridCard()`), `ConnectivityBanner`, `PremiumGate` + `LockedFeatureCard`, `MarkdownRenderer`, `PaywallSheet`, `HorizontalCardFeed`, `TopicChip`, `AnimatedScaleButton`, `AutoHideAppBar`, `SideActionRail`, `GeekyDrawer`.
