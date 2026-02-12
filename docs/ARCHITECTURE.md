# Geeky — System Architecture Document

> Comprehensive architecture for a Flutter-based adaptive educational platform that transforms multimedia notes into bite-sized learning articles ("Shorts"), organized via a Knowledge Graph, with adaptive learning paths.

---

## Table of Contents

1. [Architecture Philosophy](#1-architecture-philosophy)
2. [Technology Stack](#2-technology-stack)
3. [System Architecture Overview](#3-system-architecture-overview)
4. [Flutter Project Structure](#4-flutter-project-structure)
5. [Backend Project Structure](#5-backend-project-structure)
6. [Data Models](#6-data-models)
7. [Database Schema](#7-database-schema)
8. [State Management — Riverpod Architecture](#8-state-management--riverpod-architecture)
9. [Feature Breakdown](#9-feature-breakdown)
10. [Screens & Navigation](#10-screens--navigation)
11. [Content Processing Pipeline](#11-content-processing-pipeline)
12. [Knowledge Graph Architecture](#12-knowledge-graph-architecture)
13. [Adaptive Learning Engine](#13-adaptive-learning-engine)
14. [RAG & Knowledge Query System](#14-rag--knowledge-query-system)
15. [Spaced Repetition & Assessment](#15-spaced-repetition--assessment)
16. [Search & Discovery](#16-search--discovery)
17. [Authentication & Onboarding](#17-authentication--onboarding)
18. [Offline & Sync Strategy](#18-offline--sync-strategy)
19. [Notifications](#19-notifications)
20. [Analytics & Gamification](#20-analytics--gamification)
21. [Browser Extension Architecture](#21-browser-extension-architecture)
22. [API Design](#22-api-design)
23. [Error Handling](#23-error-handling)
24. [Security Architecture](#24-security-architecture)
25. [Testing Strategy](#25-testing-strategy)
26. [Deployment & Infrastructure](#26-deployment--infrastructure)
27. [Performance Optimization](#27-performance-optimization)
28. [Requirement Traceability](#28-requirement-traceability)

---

## 1. Architecture Philosophy

### Guiding Principles

- **Feature-first modularity**: Each feature is self-contained with its own data, domain, and presentation layers. Adding or removing a feature is a single folder operation.
- **Offline-first**: The app works without internet. All reads hit local cache first; writes queue and sync when online.
- **Event-driven processing**: Content ingestion, lifecycle changes, and user interactions trigger asynchronous pipelines — the Flutter app never waits for heavy AI processing.
- **Separation of concerns**: Flutter handles UI + local state; Firebase handles auth + real-time data + storage; Python backend handles all AI/ML workloads.
- **Minimal service count**: Three core services (Firebase, Cloud Run backend, Gemini API) plus one vector DB. No unnecessary infrastructure for a solo developer.
- **Progressive complexity**: Start simple, scale up. Use Firestore adjacency tables before Neo4j. Use `ts_rank` before Elasticsearch. Upgrade only when scale demands it.

### Architecture Pattern

The system follows a **Clean Architecture** variant adapted for Flutter + Riverpod:

```
┌─────────────────────────────────────────────┐
│              Presentation Layer              │
│   Screens, Widgets, Riverpod Providers       │
├─────────────────────────────────────────────┤
│                Domain Layer                  │
│   Entities, Use Cases, Repository Interfaces │
├─────────────────────────────────────────────┤
│                 Data Layer                   │
│   Repository Impls, Data Sources, DTOs       │
├─────────────────────────────────────────────┤
│              Infrastructure                  │
│   Firebase, HTTP Client, Local DB, Platform  │
└─────────────────────────────────────────────┘
```

**Dependency rule**: Inner layers never depend on outer layers. Domain defines repository interfaces; Data implements them. Presentation consumes domain via Riverpod providers.

---

## 2. Technology Stack

### Frontend (Flutter)

| Component | Technology | Justification |
|-----------|-----------|---------------|
| **Framework** | Flutter 3.x (Dart) | Cross-platform (Android, iOS, Web) from single codebase |
| **State Management** | Riverpod 3.0 + code generation | Type-safe, testable, auto-retry, sealed AsyncValue, provider pausing |
| **Navigation** | GoRouter | Declarative routing, deep linking, redirect guards, mature ecosystem |
| **Local Database** | Drift (SQLite) | Type-safe SQL, reactive streams, compile-time verification, robust migrations |
| **HTTP Client** | Dio + Retrofit | Interceptors (auth, logging, retry), type-safe generated API clients |
| **Models** | Freezed + json_serializable | Immutable data classes, union types, automatic serialization |
| **Markdown** | markdown_widget | Code highlighting, TOC, extensible, all platforms |
| **Charts** | fl_chart | Line, bar, pie, radar charts with animations |
| **Graph Viz** | graphview | Force-directed, tree, layered layouts for Knowledge Graph |
| **Theming** | flex_color_scheme + Material 3 | 50+ built-in schemes, proper dark mode, seed-based color generation |
| **Images** | cached_network_image | Disk + memory caching, placeholder/error widgets |
| **Animations** | flutter_animate | Declarative animation chains, stagger effects |
| **Loading States** | shimmer | Skeleton loading placeholders |

### Frontend — Feature-Specific Packages

| Feature | Package | Req IDs |
|---------|---------|---------|
| Share intent (receive) | receive_sharing_intent | MI-01, SS-02 |
| Share content (send) | share_plus | UI-04, SS-01 |
| Text-to-speech | flutter_tts | SP-07, AC-04 |
| Network monitor | connectivity_plus | OS-03 |
| File picker | file_picker + image_picker | MI-02, MI-08 |
| URL launcher | url_launcher | MI-04 |
| Notifications | firebase_messaging + flutter_local_notifications | NO-01–05 |
| Haptic feedback | HapticFeedback (Flutter SDK) | UI-12 |
| Secure storage | flutter_secure_storage | AP-05 |
| Key-value store | shared_preferences | SP-01–11 |
| **In-app purchases** | **purchases_flutter (RevenueCat)** | **SUB-01–06** |
| Swipeable cards | flutter_card_swiper / custom PageView | UI-11 |

### Backend (Python)

| Component | Technology | Justification |
|-----------|-----------|---------------|
| **Framework** | FastAPI + Pydantic v2 + uvicorn | Async-native, auto OpenAPI docs, fastest Python serialization, Cloud Run friendly |
| **AI/LLM** | Google Gemini API (gemini-2.0-flash) | Summarization, question generation, content analysis, free tier |
| **Embeddings** | gemini-embedding-001 (768 dims) | Configurable dimensions (MRL), generous free tier, GCP native |
| **Vector Store** | ChromaDB (self-hosted on Cloud Run) | Python-native, simple API, persistent storage, user-scoped collections |
| **Spaced Repetition** | FSRS (py-fsrs) | 20-30% fewer reviews than SM-2, personalized scheduling, 21 trainable parameters |
| **Graph Algorithms** | NetworkX | In-memory graph operations: PageRank, community detection, shortest path, DAG traversal |
| **NER** | spaCy (en_core_web_sm) | Named entity extraction for Knowledge Graph nodes |
| **HTML Parsing** | BeautifulSoup4 + readability-lxml | Content extraction from URLs |
| **Dedup (MinHash)** | datasketch | LSH/MinHash for near-duplicate detection |
| **Task Queue** | Cloud Tasks / in-process asyncio | Async pipeline orchestration |
| **Sanitization** | bleach | HTML sanitization on all user content |

### Infrastructure (Google Cloud + Firebase)

| Component | Technology | Req IDs |
|-----------|-----------|---------|
| **Auth** | Firebase Authentication (email/password + Google Sign-In) | AP-01–07, SE-02 |
| **Database** | Cloud Firestore (Spark plan) | MI-10, CO-01 |
| **File Storage** | Firebase Cloud Storage (5GB free) | MI-02, CO-01 |
| **Push Notifications** | Firebase Cloud Messaging (FCM) | NO-01–05 |
| **Compute** | Cloud Run (scale-to-zero) | CO-02, SC-02 |
| **Event Triggers** | Cloud Functions (Gen 2) | SYS-01–22 |
| **Secrets** | Secret Manager | SE-04 |
| **Vector DB Hosting** | Cloud Run (ChromaDB container) | CP-04, SC-05 |
| **Monitoring** | Cloud Logging + Error Reporting | MA-04, RE-04 |
| **Payments** | RevenueCat (wraps App Store + Play Store) | SUB-01–06 |

### Cost Profile (Free Tier)

| Service | Free Allowance | Fits Req |
|---------|---------------|----------|
| Firestore | 50K reads, 20K writes/day, 1GB storage | CO-01 |
| Cloud Run | 2M requests, 180K vCPU-sec/month | CO-02 |
| Cloud Storage | 5GB | CO-01 |
| Cloud Functions | 2M invocations/month | CO-03 |
| Gemini API | 15 RPM, 1M tokens/day (free tier) | CO-05 |
| Firebase Auth | 10K verifications/month | CO-01 |
| FCM | Unlimited | NO-01 |

---

## 3. System Architecture Overview

### High-Level System Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                        FLUTTER APP                               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐ │
│  │   Auth    │  │Note Feed │  │  Search  │  │  Knowledge Graph │ │
│  │  Module   │  │(Free) or │  │  & RAG   │  │  Visualization   │ │
│  │          │  │Shorts Feed│  │ (Premium)│  │   (Premium)      │ │
│  │          │  │(Premium)  │  │          │  │                  │ │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └───────┬──────────┘ │
│       │              │              │                │            │
│  ┌────┴──────────────┴──────────────┴────────────────┴──────┐    │
│  │              Riverpod Providers (State Layer)             │    │
│  ├──────────────────────────────────────────────────────────┤    │
│  │              Repository Layer (Data Abstraction)          │    │
│  ├──────────┬───────────────┬───────────────────────────────┤    │
│  │  Drift   │  Firebase SDK │  Dio (HTTP to Backend)         │    │
│  │ (Local)  │  (Direct)     │  (AI Processing)               │    │
│  └────┬─────┘──────┬────────┘──────────┬────────────────────┘    │
└───────┼────────────┼───────────────────┼─────────────────────────┘
        │            │                   │
   Local SQLite   Firebase             HTTPS
        │       ┌────┴────────┐          │
        │       │             │          │
        │  ┌────▼────┐  ┌────▼────┐  ┌──▼──────────────────────┐
        │  │Firebase  │  │Firebase  │  │   Python Backend        │
        │  │  Auth    │  │Firestore │  │   (FastAPI on Cloud Run)│
        │  └─────────┘  └─────────┘  │                          │
        │                             │  ┌──────────────────┐   │
        │  ┌──────────┐              │  │ Content Pipeline  │   │
        │  │ Firebase  │              │  │ Recommendation    │   │
        │  │ Storage   │              │  │ Knowledge Graph   │   │
        │  └──────────┘              │  │ RAG Engine        │   │
        │                             │  │ Quiz Generator    │   │
        │  ┌──────────┐              │  │ FSRS Scheduler    │   │
        │  │   FCM     │              │  └────────┬─────────┘   │
        │  │  (Push)   │              │           │              │
        │  └──────────┘              └───────────┼──────────────┘
        │                                        │
        │                              ┌─────────┼─────────┐
        │                              │         │         │
        │                         ┌────▼───┐ ┌──▼────┐ ┌──▼──────┐
        │                         │ChromaDB│ │Gemini │ │Firestore│
        │                         │(Vector)│ │  API  │ │(Admin)  │
        │                         └────────┘ └───────┘ └─────────┘
```

### Data Flow Patterns

**Pattern 1: Content Ingestion (Async Pipeline)**
```
User shares/uploads content
  → Flutter creates Note in Firestore (status: pending)
  → Cloud Function triggers on Note creation
  → Calls Python Backend /api/v1/pipeline/process
  → Backend: Extract → Chunk → Dedup → Embed → Generate Shorts → Update KG
  → Shorts written to Firestore (articles collection)
  → Flutter receives real-time update via Firestore snapshot listener
  → UI updates automatically via Riverpod StreamProvider
```

**Pattern 2: User Interaction (Real-time Feedback Loop)**
```
User marks Short as done/skip/save
  → Flutter writes interaction to Firestore
  → Cloud Function triggers on interaction write
  → Calls Python Backend /api/v1/recommendation/recalculate
  → Backend: Update user profile → Recalculate roadmap → Write next recommendation
  → Firestore user doc updated with new recommendedArticleId
  → Flutter picks up change via snapshot listener → UI shows next Short
```

**Pattern 3: RAG Query (Request-Response)**
```
User types natural language question
  → Flutter calls Python Backend /api/v1/rag/query via Dio
  → Backend: Expand query → Hybrid retrieval (vector + keyword) → Rerank → Compress → LLM generate
  → Response with answer + citations returned
  → Flutter displays answer with source links
```

**Pattern 4: Offline Read (Local-First)**
```
User opens app (no internet)
  → Riverpod provider reads from Drift (local SQLite)
  → Cached Shorts displayed immediately
  → User interactions queued in Drift pending_sync table
  → On reconnect: Drift queue flushed to Firestore
  → Firestore snapshot listener resumes real-time updates
```

---

## 4. Flutter Project Structure

### Feature-First with Internal Layering

```
geeky/
├── lib/
│   ├── main.dart                          # Entry point, bootstrap
│   ├── app.dart                           # Root MaterialApp with providers
│   ├── bootstrap.dart                     # Firebase init, Drift init, provider setup
│   │
│   ├── src/
│   │   ├── core/
│   │   │   ├── constants/
│   │   │   │   ├── app_constants.dart     # App-wide constants
│   │   │   │   ├── api_constants.dart     # API endpoints, timeouts
│   │   │   │   └── storage_keys.dart      # SharedPreferences keys
│   │   │   ├── errors/
│   │   │   │   ├── failures.dart          # Failure sealed class hierarchy
│   │   │   │   ├── exceptions.dart        # Custom exceptions
│   │   │   │   └── error_handler.dart     # Global error handler
│   │   │   ├── extensions/
│   │   │   │   ├── context_extensions.dart
│   │   │   │   ├── string_extensions.dart
│   │   │   │   └── datetime_extensions.dart
│   │   │   ├── network/
│   │   │   │   ├── dio_client.dart        # Dio setup with interceptors
│   │   │   │   ├── auth_interceptor.dart  # Firebase token injection
│   │   │   │   ├── retry_interceptor.dart # Exponential backoff
│   │   │   │   ├── logging_interceptor.dart
│   │   │   │   └── network_info.dart      # Connectivity checker
│   │   │   ├── theme/
│   │   │   │   ├── app_theme.dart         # Light + dark ThemeData
│   │   │   │   ├── app_colors.dart        # Color palette
│   │   │   │   ├── app_typography.dart    # Text styles
│   │   │   │   └── app_spacing.dart       # Consistent spacing values
│   │   │   ├── utils/
│   │   │   │   ├── debouncer.dart
│   │   │   │   ├── validators.dart        # Email, URL, input validation
│   │   │   │   └── date_formatter.dart
│   │   │   └── widgets/
│   │   │       ├── loading_widget.dart    # Shimmer loading
│   │   │       ├── error_widget.dart      # Reusable error display
│   │   │       ├── empty_state_widget.dart
│   │   │       ├── connectivity_banner.dart  # OS-03
│   │   │       ├── adaptive_layout.dart   # Responsive breakpoints (AC-05)
│   │   │       └── markdown_renderer.dart # Shared markdown rendering (SM-09)
│   │   │
│   │   ├── routing/
│   │   │   ├── app_router.dart            # GoRouter config with all routes
│   │   │   ├── route_names.dart           # Named route constants
│   │   │   └── auth_guard.dart            # Redirect unauthenticated users
│   │   │
│   │   ├── services/
│   │   │   ├── firebase/
│   │   │   │   ├── firebase_providers.dart # FirebaseAuth, Firestore, Storage providers
│   │   │   │   └── firestore_extensions.dart
│   │   │   ├── api/
│   │   │   │   ├── api_client.dart        # Retrofit-generated API client
│   │   │   │   └── api_providers.dart     # Dio + ApiClient providers
│   │   │   └── local/
│   │   │       ├── database.dart          # Drift database definition
│   │   │       ├── database.g.dart        # Generated
│   │   │       ├── tables/               # Drift table definitions
│   │   │       │   ├── cached_shorts.dart
│   │   │       │   ├── cached_modules.dart
│   │   │       │   ├── pending_interactions.dart
│   │   │       │   └── user_preferences.dart
│   │   │       └── daos/                 # Data access objects
│   │   │           ├── shorts_dao.dart
│   │   │           ├── modules_dao.dart
│   │   │           └── sync_dao.dart
│   │   │
│   │   └── features/
│   │       ├── auth/                      # AP-01–07
│   │       │   ├── data/
│   │       │   │   ├── auth_repository.dart
│   │       │   │   └── auth_dto.dart
│   │       │   ├── domain/
│   │       │   │   ├── user_entity.dart
│   │       │   │   └── auth_repository_interface.dart
│   │       │   ├── presentation/
│   │       │   │   ├── screens/
│   │       │   │   │   ├── login_screen.dart
│   │       │   │   │   ├── signup_screen.dart
│   │       │   │   │   └── forgot_password_screen.dart
│   │       │   │   └── widgets/
│   │       │   │       ├── social_login_button.dart
│   │       │   │       └── auth_form.dart
│   │       │   └── providers.dart
│   │       │
│   │       ├── onboarding/                # ON-01–06
│   │       │   ├── data/
│   │       │   │   └── onboarding_repository.dart
│   │       │   ├── domain/
│   │       │   │   ├── onboarding_step.dart
│   │       │   │   └── interest_entity.dart
│   │       │   ├── presentation/
│   │       │   │   ├── screens/
│   │       │   │   │   ├── feature_showcase_screen.dart  # ON-01
│   │       │   │   │   ├── interest_selection_screen.dart # ON-02
│   │       │   │   │   ├── source_setup_screen.dart       # ON-03
│   │       │   │   │   ├── goal_selection_screen.dart     # ON-04
│   │       │   │   │   └── proficiency_screen.dart        # ON-05
│   │       │   │   └── widgets/
│   │       │   │       ├── interest_chip.dart
│   │       │   │       ├── source_input_card.dart
│   │       │   │       └── proficiency_slider.dart
│   │       │   └── providers.dart
│   │       │
│   │       ├── home/
│   │       │   ├── presentation/
│   │       │   │   ├── screens/
│   │       │   │   │   └── home_screen.dart  # Shell with bottom nav
│   │       │   │   └── widgets/
│   │       │   │       └── bottom_nav_bar.dart
│   │       │   └── providers.dart
│   │       │
│   │       ├── shorts/                    # SM-01–10, UI-01–12
│   │       │   ├── data/
│   │       │   │   ├── shorts_repository.dart
│   │       │   │   ├── shorts_remote_source.dart   # Firestore
│   │       │   │   ├── shorts_local_source.dart    # Drift cache
│   │       │   │   └── short_dto.dart
│   │       │   ├── domain/
│   │       │   │   ├── short_entity.dart
│   │       │   │   ├── engagement_metrics.dart
│   │       │   │   ├── exploration_prompt.dart
│   │       │   │   └── shorts_repository_interface.dart
│   │       │   ├── presentation/
│   │       │   │   ├── screens/
│   │       │   │   │   ├── shorts_feed_screen.dart     # Card-based swipeable feed
│   │       │   │   │   └── short_detail_screen.dart    # Full article reader
│   │       │   │   └── widgets/
│   │       │   │       ├── short_card.dart              # Swipeable card
│   │       │   │       ├── short_actions_bar.dart       # Done/Skip/Save/Share
│   │       │   │       ├── navigation_options.dart      # Deeper/Up/Next/Related
│   │       │   │       ├── exploration_prompts_list.dart
│   │       │   │       ├── recommendation_reason.dart   # PR-06
│   │       │   │       └── engagement_tracker.dart      # Time + scroll tracking
│   │       │   └── providers.dart
│   │       │
│   │       ├── modules/                   # MO-01–09
│   │       │   ├── data/
│   │       │   │   ├── modules_repository.dart
│   │       │   │   └── module_dto.dart
│   │       │   ├── domain/
│   │       │   │   ├── module_entity.dart
│   │       │   │   └── module_progress.dart
│   │       │   ├── presentation/
│   │       │   │   ├── screens/
│   │       │   │   │   ├── modules_list_screen.dart
│   │       │   │   │   ├── module_detail_screen.dart
│   │       │   │   │   └── create_module_screen.dart   # MO-03
│   │       │   │   └── widgets/
│   │       │   │       ├── module_card.dart
│   │       │   │       ├── module_progress_bar.dart    # MO-08
│   │       │   │       └── module_short_list.dart
│   │       │   └── providers.dart
│   │       │
│   │       ├── knowledge_graph/           # KG-01–17
│   │       │   ├── data/
│   │       │   │   ├── kg_repository.dart
│   │       │   │   └── kg_dto.dart
│   │       │   ├── domain/
│   │       │   │   ├── concept_entity.dart
│   │       │   │   ├── relationship_entity.dart
│   │       │   │   └── graph_node.dart
│   │       │   ├── presentation/
│   │       │   │   ├── screens/
│   │       │   │   │   └── knowledge_graph_screen.dart  # KG-13
│   │       │   │   └── widgets/
│   │       │   │       ├── graph_visualization.dart     # Interactive graph
│   │       │   │       ├── graph_node_widget.dart       # Node with status colors
│   │       │   │       ├── graph_legend.dart
│   │       │   │       └── graph_controls.dart          # Zoom, pan, filter
│   │       │   └── providers.dart
│   │       │
│   │       ├── search/                    # SD-01–06
│   │       │   ├── data/
│   │       │   │   └── search_repository.dart
│   │       │   ├── domain/
│   │       │   │   ├── search_result.dart
│   │       │   │   └── search_filter.dart
│   │       │   ├── presentation/
│   │       │   │   ├── screens/
│   │       │   │   │   └── search_screen.dart
│   │       │   │   └── widgets/
│   │       │   │       ├── search_bar_widget.dart
│   │       │   │       ├── search_filters.dart         # SD-02
│   │       │   │       ├── search_result_card.dart
│   │       │   │       └── search_suggestions.dart     # SD-06
│   │       │   └── providers.dart
│   │       │
│   │       ├── rag_query/                 # RQ-01–13
│   │       │   ├── data/
│   │       │   │   └── rag_repository.dart
│   │       │   ├── domain/
│   │       │   │   ├── rag_response.dart
│   │       │   │   ├── citation.dart
│   │       │   │   └── chat_message.dart
│   │       │   ├── presentation/
│   │       │   │   ├── screens/
│   │       │   │   │   ├── rag_chat_screen.dart        # RQ-01, RQ-05
│   │       │   │   │   └── mind_map_screen.dart        # RQ-13
│   │       │   │   └── widgets/
│   │       │   │       ├── chat_bubble.dart
│   │       │   │       ├── citation_chip.dart          # RQ-03
│   │       │   │       ├── audio_summary_player.dart   # RQ-10
│   │       │   │       └── mind_map_view.dart
│   │       │   └── providers.dart
│   │       │
│   │       ├── quiz/                      # RA-01–12
│   │       │   ├── data/
│   │       │   │   └── quiz_repository.dart
│   │       │   ├── domain/
│   │       │   │   ├── quiz_entity.dart
│   │       │   │   ├── question_entity.dart
│   │       │   │   └── quiz_result.dart
│   │       │   ├── presentation/
│   │       │   │   ├── screens/
│   │       │   │   │   ├── quiz_screen.dart
│   │       │   │   │   ├── quiz_result_screen.dart
│   │       │   │   │   └── spaced_review_screen.dart   # RA-01
│   │       │   │   └── widgets/
│   │       │   │       ├── question_card.dart
│   │       │   │       ├── multiple_choice_widget.dart  # RA-08
│   │       │   │       ├── true_false_widget.dart
│   │       │   │       ├── fill_blank_widget.dart
│   │       │   │       ├── open_ended_widget.dart
│   │       │   │       └── retention_indicator.dart     # RA-06
│   │       │   └── providers.dart
│   │       │
│   │       ├── analytics/                 # AT-01–08
│   │       │   ├── data/
│   │       │   │   └── analytics_repository.dart
│   │       │   ├── domain/
│   │       │   │   ├── learning_streak.dart
│   │       │   │   ├── topic_progress.dart
│   │       │   │   └── achievement.dart
│   │       │   ├── presentation/
│   │       │   │   ├── screens/
│   │       │   │   │   ├── analytics_dashboard_screen.dart  # AT-05
│   │       │   │   │   └── achievements_screen.dart         # AT-08
│   │       │   │   └── widgets/
│   │       │   │       ├── streak_widget.dart                # AT-01
│   │       │   │       ├── stats_summary.dart                # AT-02
│   │       │   │       ├── topic_progress_chart.dart         # AT-03
│   │       │   │       ├── reading_history_list.dart         # AT-04
│   │       │   │       ├── engagement_chart.dart             # AT-05
│   │       │   │       ├── learning_velocity_widget.dart     # AT-07
│   │       │   │       └── badge_grid.dart                   # AT-08
│   │       │   └── providers.dart
│   │       │
│   │       ├── profile/                   # AP-03–04, UP-01–10
│   │       │   ├── data/
│   │       │   │   └── profile_repository.dart
│   │       │   ├── domain/
│   │       │   │   ├── user_profile_entity.dart
│   │       │   │   ├── learner_model.dart
│   │       │   │   └── familiarity_score.dart
│   │       │   ├── presentation/
│   │       │   │   ├── screens/
│   │       │   │   │   ├── profile_screen.dart
│   │       │   │   │   └── edit_profile_screen.dart
│   │       │   │   └── widgets/
│   │       │   │       ├── profile_header.dart
│   │       │   │       ├── expertise_radar.dart          # UP-04
│   │       │   │       └── knowledge_overlay_widget.dart  # UP-07
│   │       │   └── providers.dart
│   │       │
│   │       ├── settings/                  # SP-01–11
│   │       │   ├── data/
│   │       │   │   └── settings_repository.dart
│   │       │   ├── domain/
│   │       │   │   └── app_settings.dart
│   │       │   ├── presentation/
│   │       │   │   ├── screens/
│   │       │   │   │   ├── settings_screen.dart
│   │       │   │   │   └── data_management_screen.dart  # SP-08–10
│   │       │   │   └── widgets/
│   │       │   │       ├── theme_selector.dart           # SP-01
│   │       │   │       ├── font_size_slider.dart         # SP-02
│   │       │   │       └── tts_settings.dart             # SP-07
│   │       │   └── providers.dart
│   │       │
│   │       ├── sources/                   # CS-01–07, MI-05–09
│   │       │   ├── data/
│   │       │   │   └── sources_repository.dart
│   │       │   ├── domain/
│   │       │   │   ├── content_source_entity.dart
│   │       │   │   └── source_health.dart
│   │       │   ├── presentation/
│   │       │   │   ├── screens/
│   │       │   │   │   ├── sources_list_screen.dart
│   │       │   │   │   ├── source_detail_screen.dart     # CS-03–04
│   │       │   │   │   └── add_source_screen.dart        # CS-01
│   │       │   │   └── widgets/
│   │       │   │       ├── source_card.dart
│   │       │   │       ├── source_health_badge.dart      # CS-03
│   │       │   │       └── predefined_sources_grid.dart  # CS-07
│   │       │   └── providers.dart
│   │       │
│   │       ├── notes/                     # MI-01–13
│   │       │   ├── data/
│   │       │   │   ├── notes_repository.dart
│   │       │   │   └── note_dto.dart
│   │       │   ├── domain/
│   │       │   │   ├── note_entity.dart
│   │       │   │   └── media_type.dart
│   │       │   ├── presentation/
│   │       │   │   ├── screens/
│   │       │   │   │   ├── notes_list_screen.dart
│   │       │   │   │   ├── note_detail_screen.dart
│   │       │   │   │   ├── create_note_screen.dart       # MI-03
│   │       │   │   │   └── upload_media_screen.dart      # MI-02
│   │       │   │   └── widgets/
│   │       │   │       ├── note_card.dart
│   │       │   │       ├── processing_status_badge.dart  # LM-08
│   │       │   │       ├── source_summary_card.dart      # MI-13
│   │       │   │       └── media_preview.dart
│   │       │   └── providers.dart
│   │       │
│   │       ├── bookmarks/                 # UI-03
│   │       │   ├── data/
│   │       │   │   └── bookmarks_repository.dart
│   │       │   ├── presentation/
│   │       │   │   ├── screens/
│   │       │   │   │   └── bookmarks_screen.dart
│   │       │   │   └── widgets/
│   │       │   │       └── bookmark_card.dart
│   │       │   └── providers.dart
│   │       │
│   │       ├── notifications/             # NO-01–05
│   │       │   ├── data/
│   │       │   │   └── notifications_repository.dart
│   │       │   ├── domain/
│   │       │   │   └── notification_entity.dart
│   │       │   ├── presentation/
│   │       │   │   ├── screens/
│   │       │   │   │   └── notifications_screen.dart
│   │       │   │   └── widgets/
│   │       │   │       └── notification_tile.dart
│   │       │   └── providers.dart
│   │       │
│   │       └── offline/                   # OS-01–06
│   │           ├── data/
│   │           │   ├── sync_repository.dart
│   │           │   └── offline_queue.dart
│   │           ├── domain/
│   │           │   └── sync_status.dart
│   │           └── providers.dart
│   │
├── test/                                  # Mirrors lib/src structure
│   ├── src/
│   │   ├── core/
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   ├── shorts/
│   │   │   └── ...
│   │   └── helpers/
│   │       ├── pump_app.dart              # Test wrapper with providers
│   │       ├── mocks.dart                 # Mocktail mocks
│   │       └── fakes.dart                 # Fake implementations
│   └── integration/
│       └── critical_flows_test.dart
│
├── assets/
│   ├── images/
│   ├── icons/
│   ├── animations/                        # Lottie files
│   └── fonts/
│
├── android/
├── ios/
├── web/
├── pubspec.yaml
├── analysis_options.yaml
├── build.yaml                             # Code generation config
└── docs/
    ├── REQUIREMENTS.md
    ├── ARCHITECTURE.md                    # This document
    └── extra/
```

### Code Generation Setup

The project uses code generation for Riverpod, Freezed, Retrofit, and Drift. Run with:

```bash
dart run build_runner build --delete-conflicting-outputs
```

**build.yaml** configuration ensures generators run in correct order: freezed → json_serializable → retrofit → riverpod.

---

## 5. Backend Project Structure

```
geeky-backend/
├── main.py                              # FastAPI app entry + uvicorn
├── requirements.txt
├── Dockerfile
├── .env.example
│
├── config/
│   ├── settings.py                      # Pydantic BaseSettings (env vars)
│   ├── firebase_config.py               # Firebase Admin SDK init
│   └── chroma_config.py                 # ChromaDB client config
│
├── app/
│   ├── api/
│   │   ├── routes/
│   │   │   ├── notes.py                 # POST /notes, PUT /notes/{id}
│   │   │   ├── articles.py              # GET /articles, GET /articles/{id}
│   │   │   ├── users.py                 # GET/PUT /users/{id}/profile
│   │   │   ├── recommendations.py       # GET /recommendations, POST /recalculate
│   │   │   ├── rag.py                   # POST /rag/query, POST /rag/follow-up
│   │   │   ├── quiz.py                  # POST /quiz/generate, POST /quiz/grade
│   │   │   ├── search.py               # GET /search
│   │   │   ├── knowledge_graph.py       # GET /kg/nodes, GET /kg/navigate
│   │   │   ├── modules.py              # CRUD /modules
│   │   │   ├── sources.py              # CRUD /sources, POST /sources/validate
│   │   │   └── analytics.py            # GET /analytics/dashboard
│   │   ├── middleware/
│   │   │   ├── auth.py                  # Firebase token verification
│   │   │   ├── rate_limiting.py         # Per-user rate limits (SE-05)
│   │   │   └── cors.py                  # CORS whitelist (SE-07)
│   │   └── dependencies.py              # FastAPI Depends (auth, db, chroma)
│   │
│   ├── models/                          # Pydantic request/response models
│   │   ├── note.py
│   │   ├── article.py
│   │   ├── user.py
│   │   ├── chunk.py
│   │   ├── recommendation.py
│   │   ├── quiz.py
│   │   ├── search.py
│   │   └── knowledge_graph.py
│   │
│   ├── services/
│   │   ├── pipeline/                    # Content Processing Pipeline (CP-01–24)
│   │   │   ├── orchestrator.py          # Pipeline coordinator
│   │   │   ├── extractors/
│   │   │   │   ├── base.py              # Abstract extractor
│   │   │   │   ├── text_extractor.py    # CP-01 (TEXT)
│   │   │   │   ├── image_extractor.py   # CP-01 (IMAGE - Gemini Vision)
│   │   │   │   ├── audio_extractor.py   # CP-01 (AUDIO - STT)
│   │   │   │   ├── link_extractor.py    # CP-01 (LINK - BeautifulSoup)
│   │   │   │   ├── video_extractor.py   # CP-01 (VIDEO)
│   │   │   │   └── file_extractor.py    # CP-01 (FILE - PDF/DOCX)
│   │   │   ├── chunker.py              # CP-03 (hierarchical chunking)
│   │   │   ├── chunk_validator.py       # CP-04a (coherence validation)
│   │   │   ├── deduplication/
│   │   │   │   ├── exact_dedup.py       # CP-05a (SHA-256 hash)
│   │   │   │   ├── near_dedup.py        # CP-05b (MinHash/LSH)
│   │   │   │   ├── semantic_dedup.py    # CP-05c (embedding cosine)
│   │   │   │   ├── cross_modal_dedup.py # CP-05d
│   │   │   │   ├── streaming_dedup.py   # CP-19 (Bloom filter)
│   │   │   │   └── dedup_logger.py      # CP-18 (audit log)
│   │   │   ├── embedder.py             # CP-04 (Gemini embedding)
│   │   │   ├── summarizer.py           # CP-07 (Short generation)
│   │   │   ├── topic_tagger.py         # CP-09 (topic extraction)
│   │   │   ├── difficulty_scorer.py    # CP-10
│   │   │   ├── exploration_gen.py      # CP-11 (question generation)
│   │   │   ├── ner_extractor.py        # CP-13 (spaCy NER)
│   │   │   ├── conflict_detector.py    # CP-16
│   │   │   ├── anti_density.py         # CP-17
│   │   │   ├── canonicalizer.py        # CP-20
│   │   │   └── concept_discovery.py    # CP-22 (clustering + labeling)
│   │   │
│   │   ├── vector_store/
│   │   │   ├── chroma_client.py         # ChromaDB operations
│   │   │   ├── embedding_service.py     # Embedding generation + metadata (CP-04b)
│   │   │   ├── hybrid_search.py         # Vector + keyword search (CP-23)
│   │   │   └── index_manager.py         # Multiple index types (CP-23)
│   │   │
│   │   ├── knowledge_graph/             # KG-01–17
│   │   │   ├── graph_builder.py         # Build/update graph from Shorts
│   │   │   ├── graph_navigator.py       # Dive deeper, go up, next, related
│   │   │   ├── traversal_engine.py      # Universal traversal guarantee (KG-08)
│   │   │   ├── graph_store.py           # Firestore adjacency tables
│   │   │   └── temporal_tracker.py      # KG-16 (concept evolution)
│   │   │
│   │   ├── recommendation/             # AL-01–13
│   │   │   ├── engine.py               # Multi-factor scoring (AL-02)
│   │   │   ├── user_modeler.py         # Bayesian Knowledge Tracing (AL-09)
│   │   │   ├── roadmap_calculator.py   # Dynamic path resequencing (AL-01)
│   │   │   ├── cold_start.py           # AL-08
│   │   │   ├── diversity_balancer.py   # AL-06, AL-11
│   │   │   └── context_analyzer.py     # AL-12 (time, device, session)
│   │   │
│   │   ├── rag/                         # RQ-01–13
│   │   │   ├── query_engine.py         # RAG orchestrator
│   │   │   ├── query_expander.py       # RQ-11
│   │   │   ├── hybrid_retriever.py     # RQ-02 (dense + sparse)
│   │   │   ├── reranker.py             # RQ-07 (cross-encoder)
│   │   │   ├── mmr_diversifier.py      # RQ-08
│   │   │   ├── context_compressor.py   # RQ-09
│   │   │   ├── answer_generator.py     # Grounded generation with citations
│   │   │   ├── audio_summary.py        # RQ-10 (TTS generation)
│   │   │   ├── mind_map_generator.py   # RQ-13
│   │   │   └── task_profiles.py        # RQ-12 (task-specific retrieval config)
│   │   │
│   │   ├── assessment/                  # RA-01–12
│   │   │   ├── quiz_generator.py       # RA-02, RA-08
│   │   │   ├── quiz_grader.py          # AI-graded open-ended (RA-08)
│   │   │   ├── concept_inventory.py    # RA-09
│   │   │   ├── fsrs_scheduler.py       # RA-01 (FSRS integration)
│   │   │   └── output_dedup.py         # RA-11 (Q&A deduplication)
│   │   │
│   │   ├── lifecycle/                   # LM-01–08
│   │   │   ├── note_lifecycle.py       # LM-01–02 (edit/delete cascades)
│   │   │   ├── short_lifecycle.py      # SM-03–05 (auto-update/merge/delete)
│   │   │   ├── module_lifecycle.py     # LM-06 (module recalculation)
│   │   │   └── cascade_manager.py      # LM-03–04 (cascading deletes)
│   │   │
│   │   ├── sources/                     # CS-01–07
│   │   │   ├── source_poller.py        # CS-06 (RSS/URL polling)
│   │   │   ├── source_validator.py     # CS-05
│   │   │   └── rss_parser.py           # MI-05
│   │   │
│   │   └── firestore/
│   │       ├── base_service.py          # CRUD abstractions
│   │       ├── notes_service.py
│   │       ├── articles_service.py
│   │       ├── users_service.py
│   │       ├── modules_service.py
│   │       └── interactions_service.py
│   │
│   └── utils/
│       ├── logger.py                    # Structured JSON logging (MA-04)
│       ├── validators.py                # Input validation (SE-06)
│       ├── sanitizer.py                 # Bleach HTML sanitization (SE-06)
│       ├── rate_limiter.py              # Token bucket (SE-05)
│       └── correlation_id.py            # Request tracing (MA-04)
│
├── cloud_functions/
│   ├── on_note_created.py               # SYS-01: Triggers processing pipeline
│   ├── on_note_updated.py               # SYS-08: Re-process note
│   ├── on_note_deleted.py               # SYS-09: Cascade delete
│   ├── on_interaction_created.py        # SYS-04: Recalculate roadmap
│   ├── on_short_created.py              # SYS-03: Update KG + modules
│   ├── on_source_poll.py                # SYS-02: Scheduled source polling
│   └── on_daily_streak.py               # SYS-15: Streak tracking
│
├── tests/
│   ├── unit/
│   ├── integration/
│   └── fixtures/
│
└── scripts/
    ├── deploy.sh
    └── seed_data.py
```

---

## 6. Data Models

All Flutter models use **Freezed** for immutability, union types, and auto-generated `copyWith`, `==`, `hashCode`, `toString`, plus **json_serializable** for Firestore/JSON serialization.

### 6.1 User Entity

```dart
@freezed
class UserEntity with _$UserEntity {
  const factory UserEntity({
    required String id,
    required String email,
    String? displayName,
    String? photoURL,
    @Default(UserQualities()) UserQualities qualities,
    @Default(UserPreferences()) UserPreferences preferences,
    @Default(UserSettings()) UserSettings settings,
    @Default(UserStats()) UserStats stats,
    String? recommendedArticleId,
    @Default(false) bool isGuest,
    @Default(SubscriptionInfo()) SubscriptionInfo subscription,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _UserEntity;
}

/// Subscription tier and status
enum SubscriptionTier { free, premium }

@freezed
class SubscriptionInfo with _$SubscriptionInfo {
  const factory SubscriptionInfo({
    @Default(SubscriptionTier.free) SubscriptionTier tier,
    String? revenueCatId,       // RevenueCat customer ID
    String? productId,          // Active product ID (monthly/yearly)
    DateTime? expiresAt,        // Null for free tier
    @Default(false) bool isTrialing,
  }) = _SubscriptionInfo;

  const SubscriptionInfo._();

  bool get isPremium => tier == SubscriptionTier.premium &&
    (expiresAt == null || expiresAt!.isAfter(DateTime.now()));
}

@freezed
class UserQualities with _$UserQualities {
  const factory UserQualities({
    @Default('visual') String learningMode, // visual | auditory | kinesthetic
    @Default([]) List<String> strengths,
    @Default([]) List<String> weaknesses,
    @Default('medium') String contentDepth, // brief | medium | detailed (UP-10)
  }) = _UserQualities;
}

@freezed
class UserPreferences with _$UserPreferences {
  const factory UserPreferences({
    @Default([]) List<String> interests,          // ON-02, SP-04
    @Default([]) List<String> goals,              // ON-04
    @Default('en') String language,               // SP-03
    @Default({}) Map<String, double> topicFamiliarity, // UP-02: topic → 0.0–1.0
    @Default({}) Map<String, int> topicExpertise,      // UP-04: topic → 0–100
  }) = _UserPreferences;
}

@freezed
class UserSettings with _$UserSettings {
  const factory UserSettings({
    @Default('system') String themeMode,  // SP-01: light | dark | system
    @Default('medium') String fontSize,   // SP-02: small | medium | large
    @Default(true) bool notificationsEnabled,
    @Default(true) bool ttsEnabled,       // SP-07
    @Default({}) Map<String, bool> notificationTopics, // NO-02
  }) = _UserSettings;
}

@freezed
class UserStats with _$UserStats {
  const factory UserStats({
    @Default(0) int completedCount,       // AT-02
    @Default(0) int skippedCount,
    @Default(0) int streakDays,           // AT-01
    @Default(0) int bestStreak,           // AT-01
    DateTime? lastActivityDate,
    @Default(0) int totalTimeSpentSeconds, // AT-02
    @Default(0) int topicsCovered,         // AT-02
    @Default([]) List<String> badges,      // AT-08
  }) = _UserStats;
}
```

### 6.2 Note Entity

```dart
enum MediaType { text, image, audio, link, video, file }

@freezed
class NoteEntity with _$NoteEntity {
  const factory NoteEntity({
    required String id,
    required String userId,
    required MediaType type,          // MI-01–08
    String? title,
    String? content,                  // Raw text content (MI-03)
    String? extractedText,            // Post-processing extracted text (CP-02)
    String? mediaUrl,                 // Cloud Storage URL for primary media file
    String? sourceUrl,                // Original URL if type == link (MI-04)
    @Default([]) List<NoteMedia> mediaAssets, // All images/media in this note
    @Default(false) bool processed,
    @Default([]) List<String> chunkIds,
    @Default([]) List<String> shortIds,
    @Default({}) Map<String, dynamic> metadata,
    @Default(0) int wordCount,        // For free-tier feed scoring
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _NoteEntity;
}

/// Media asset attached to a note (images, diagrams, charts, etc.)
@freezed
class NoteMedia with _$NoteMedia {
  const factory NoteMedia({
    required String id,
    required String storageUrl,    // Cloud Storage URL
    required String type,          // image | diagram | chart | screenshot
    String? altText,               // Gemini Vision description
    String? caption,               // User-provided caption
    @Default(0) int positionIndex, // Order within the note
  }) = _NoteMedia;
}
```

### 6.3 Short (Article) Entity

```dart
@freezed
class ShortEntity with _$ShortEntity {
  const factory ShortEntity({
    required String id,
    required String userId,
    required String title,
    required String content,          // Markdown (SM-09)
    required String summary,
    @Default([]) List<String> topics,          // CP-09
    @Default([]) List<String> tags,
    @Default(0.5) double difficulty,           // CP-10: 0.0–1.0
    @Default(1) int level,                     // KG-02: hierarchy level
    @Default([]) List<String> prerequisites,   // SM-06
    @Default([]) List<RelatedShort> relatedArticles, // SM-07
    @Default([]) List<Citation> citations,     // Source note + chunk refs
    @Default([]) List<String> explorationPrompts,    // CP-11
    @Default([]) List<String> conceptIds,      // KG concept references
    @Default([]) List<ShortMedia> media,       // Images reused from source notes
    @Default(EngagementMetrics()) EngagementMetrics engagement, // SM-08
    String? sourceType,                        // 'pipeline' | 'store' (origin)
    String? storeShortId,                      // If downloaded from Module Store
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(1) int version,                   // SM-10
  }) = _ShortEntity;
}

/// Media embedded in a Short, reused from source notes when relevant
@freezed
class ShortMedia with _$ShortMedia {
  const factory ShortMedia({
    required String storageUrl,    // Cloud Storage URL (same as source note)
    required String type,          // image | diagram | chart
    required String altText,       // Description (from Gemini Vision analysis)
    @Default(0.0) double relevanceScore, // How relevant this image is to the Short
  }) = _ShortMedia;
}

@freezed
class RelatedShort with _$RelatedShort {
  const factory RelatedShort({
    required String articleId,
    required String type, // deeper | broader | next | similar | prerequisite
    @Default(0.0) double relevanceScore,
  }) = _RelatedShort;
}

@freezed
class Citation with _$Citation {
  const factory Citation({
    required String noteId,
    required String chunkId,
    String? sectionTitle,
    String? sourceUrl,
  }) = _Citation;
}

@freezed
class EngagementMetrics with _$EngagementMetrics {
  const factory EngagementMetrics({
    @Default(0) int viewCount,
    @Default(0) int completionCount,
    @Default(0) int skipCount,
    @Default(0) int saveCount,
    @Default(0) int shareCount,
    @Default(0) double avgTimeSpentSeconds,
    @Default(0.0) double engagementScore,
  }) = _EngagementMetrics;
}
```

### 6.4 Module Entity

```dart
@freezed
class ModuleEntity with _$ModuleEntity {
  const factory ModuleEntity({
    required String id,
    required String userId,
    required String name,
    String? description,
    @Default([]) List<String> topics,
    @Default([]) List<String> shortIds,
    required String type,                         // auto | manual (MO-02, MO-03)
    @Default([]) List<AdaptiveRule> adaptiveRules, // MO-09
    @Default(ModuleProgress()) ModuleProgress progress, // MO-08
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _ModuleEntity;
}

@freezed
class ModuleProgress with _$ModuleProgress {
  const factory ModuleProgress({
    @Default(0) int totalShorts,
    @Default(0) int completedShorts,
    @Default(0) int currentPosition,
    @Default(0) double estimatedMinutesRemaining,
  }) = _ModuleProgress;
}

@freezed
class AdaptiveRule with _$AdaptiveRule {
  const factory AdaptiveRule({
    required String condition,  // e.g., "familiarity > 0.8"
    required String action,     // e.g., "skip", "summarize", "reorder"
    @Default({}) Map<String, dynamic> params,
  }) = _AdaptiveRule;
}
```

### 6.5 UserInteraction Entity

```dart
enum InteractionType { started, completed, skipped, bookmarked, shared, feedback }

@freezed
class UserInteraction with _$UserInteraction {
  const factory UserInteraction({
    required String id,
    required String articleId,
    required InteractionType type,
    required DateTime timestamp,
    @Default(0) double timeSpentSeconds,      // UI-07
    @Default(0.0) double scrollDepth,          // UI-08: 0.0–1.0
    String? device,
    String? feedbackType, // too_easy | too_hard | not_relevant (UI-10)
    String? navigationDirection, // deeper | up | next | related (UP-05)
    String? fromArticleId,       // Navigation source
  }) = _UserInteraction;
}
```

### 6.6 ContentSource Entity

```dart
enum SourceType { website, rss, newsletter, api, socialFeed }
enum SourceStatus { active, paused, error }

@freezed
class ContentSourceEntity with _$ContentSourceEntity {
  const factory ContentSourceEntity({
    required String id,
    required String userId,
    required String name,
    required SourceType type,
    required String url,
    @Default(Duration(minutes: 30)) Duration fetchFrequency, // CS-02
    @Default(SourceStatus.active) SourceStatus status,       // CS-03
    String? errorMessage,
    @Default([]) List<String> defaultTopics,
    @Default({}) Map<String, String> fieldMappings,  // CS-02
    @Default(SourceStats()) SourceStats stats,       // CS-04
    required DateTime createdAt,
    DateTime? lastFetchedAt,
  }) = _ContentSourceEntity;
}

@freezed
class SourceStats with _$SourceStats {
  const factory SourceStats({
    @Default(0) int totalFetched,
    @Default(0) int successCount,
    @Default(0) int errorCount,
    @Default(0.0) double successRate,
  }) = _SourceStats;
}
```

### 6.7 Knowledge Graph Entities

```dart
@freezed
class ConceptEntity with _$ConceptEntity {
  const factory ConceptEntity({
    required String id,
    required String name,
    String? description,
    @Default(1) int level,                    // KG-02
    @Default([]) List<String> aliases,
    @Default([]) List<String> articleIds,
    @Default(0.0) double importanceScore,     // CP-22
    required DateTime createdAt,
    DateTime? lastUpdatedAt,                  // KG-16
  }) = _ConceptEntity;
}

@freezed
class RelationshipEntity with _$RelationshipEntity {
  const factory RelationshipEntity({
    required String id,
    required String sourceId,
    required String targetId,
    required String type, // prerequisite | related | part_of | deeper | broader | example_of
    @Default(1.0) double strength,
    @Default(false) bool isDynamic, // KG-17: soft/dynamic edges
    required DateTime createdAt,
  }) = _RelationshipEntity;
}

// Graph node for visualization (KG-13)
@freezed
class GraphNode with _$GraphNode {
  const factory GraphNode({
    required String id,
    required String label,
    required int level,
    required NodeStatus status, // mastered | in_progress | unread | locked
    @Default([]) List<String> connectedNodeIds,
  }) = _GraphNode;
}

enum NodeStatus { mastered, inProgress, unread, locked }
```

### 6.8 Quiz / Assessment Entity

```dart
enum QuestionType { multipleChoice, trueFalse, fillBlank, openEnded, shortAnswer }

@freezed
class QuizEntity with _$QuizEntity {
  const factory QuizEntity({
    required String id,
    required String userId,
    required String articleId,
    String? moduleId,
    @Default([]) List<QuestionEntity> questions,
    @Default([]) List<String> answers,
    double? score,
    @Default({}) Map<String, double> retentionMetrics, // Per-concept
    required DateTime createdAt,
  }) = _QuizEntity;
}

@freezed
class QuestionEntity with _$QuestionEntity {
  const factory QuestionEntity({
    required String id,
    required String text,
    required QuestionType type,              // RA-08
    @Default([]) List<String> options,        // For MC
    required String correctAnswer,
    String? explanation,
    String? conceptId,                       // RA-10
    @Default(0.5) double difficulty,          // RA-07
    @Default([]) List<String> conflictingSources, // RA-12
  }) = _QuestionEntity;
}
```

### 6.9 RAG / Chat Entities

```dart
@freezed
class ChatMessage with _$ChatMessage {
  const factory ChatMessage.user({
    required String id,
    required String content,
    required DateTime timestamp,
  }) = UserMessage;

  const factory ChatMessage.assistant({
    required String id,
    required String content,
    @Default([]) List<RagCitation> citations, // RQ-03
    required DateTime timestamp,
  }) = AssistantMessage;
}

@freezed
class RagCitation with _$RagCitation {
  const factory RagCitation({
    required String shortId,
    required String shortTitle,
    String? noteId,
    required String snippetText,
    required double relevanceScore,
  }) = _RagCitation;
}

@freezed
class RagResponse with _$RagResponse {
  const factory RagResponse({
    required String answer,
    required List<RagCitation> citations,
    @Default([]) List<String> followUpQuestions,
  }) = _RagResponse;
}
```

### 6.10 Spaced Repetition State (FSRS)

```dart
@freezed
class FSRSCardState with _$FSRSCardState {
  const factory FSRSCardState({
    required String articleId,
    required double stability,     // Days until 90% recall probability
    required double difficulty,    // 0.0–1.0
    required DateTime dueDate,
    required int reps,
    required int lapses,
    @Default('new') String state,  // new | learning | review | relearning
    DateTime? lastReviewDate,
  }) = _FSRSCardState;
}
```

### 6.11 Analytics Entities

```dart
@freezed
class LearningStreak with _$LearningStreak {
  const factory LearningStreak({
    @Default(0) int currentStreak,     // AT-01
    @Default(0) int bestStreak,        // AT-01
    DateTime? lastActivityDate,
    @Default(false) bool atRisk,       // Hasn't engaged today
  }) = _LearningStreak;
}

@freezed
class Achievement with _$Achievement {
  const factory Achievement({
    required String id,
    required String name,
    required String description,
    required String iconAsset,
    required bool unlocked,
    DateTime? unlockedAt,
    @Default(0.0) double progress, // 0.0–1.0
  }) = _Achievement;
}

@freezed
class TopicProgress with _$TopicProgress {
  const factory TopicProgress({
    required String topic,
    @Default(0) int totalShorts,
    @Default(0) int completedShorts,
    @Default(0.0) double expertiseLevel,   // UP-04: 0–100
    @Default(0.0) double familiarity,      // UP-02: 0.0–1.0
    @Default(0.0) double retentionRate,    // RA-06
  }) = _TopicProgress;
}
```

### 6.12 Recommendation Entity

```dart
@freezed
class Recommendation with _$Recommendation {
  const factory Recommendation({
    required String articleId,
    required double score,
    required String reason,          // PR-06: transparent AI
    required String explanation,
    @Default({}) Map<String, double> scoreBreakdown, // AL-02: relevance, capability, novelty
  }) = _Recommendation;
}
```

### 6.13 Notification Entity

```dart
enum NotificationType { newShort, reviewReminder, streakReminder, sourceUpdate, achievement }

@freezed
class NotificationEntity with _$NotificationEntity {
  const factory NotificationEntity({
    required String id,
    required NotificationType type,
    required String title,
    required String body,
    String? deepLinkRoute, // NO-04
    @Default(false) bool read,
    required DateTime createdAt,
  }) = _NotificationEntity;
}
```

### 6.14 Processing Task Entity

```dart
enum TaskStatus { pending, processing, completed, failed }
enum TaskType { ingest, update, delete }

@freezed
class ProcessingTask with _$ProcessingTask {
  const factory ProcessingTask({
    required String id,
    required String userId,
    required String noteId,
    required TaskType taskType,
    @Default(TaskStatus.pending) TaskStatus status,  // LM-08
    String? errorMessage,
    @Default(0.0) double progress, // 0.0–1.0
    required DateTime createdAt,
    DateTime? completedAt,
  }) = _ProcessingTask;
}
```

### 6.15 Module Store Entities

```dart
/// A pre-made module available for download from the app-owner store
@freezed
class StoreModuleEntity with _$StoreModuleEntity {
  const factory StoreModuleEntity({
    required String id,
    required String name,
    required String description,
    @Default([]) List<String> topics,
    required int shortCount,
    required double estimatedMinutes,
    @Default(0.5) double avgDifficulty,
    String? coverImageUrl,
    @Default(0) int downloadCount,
    @Default(0) int version,       // For update detection
    required String createdBy,     // "app_owner" or future creator ID
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _StoreModuleEntity;
}

/// A pre-made short within a store module
@freezed
class StoreShortEntity with _$StoreShortEntity {
  const factory StoreShortEntity({
    required String id,
    required String storeModuleId,
    required String title,
    required String content,       // Markdown
    required String summary,
    @Default([]) List<String> topics,
    @Default(0.5) double difficulty,
    @Default(1) int level,
    @Default([]) List<String> explorationPrompts,
    @Default([]) List<ShortMedia> media,
    @Default(0) int orderIndex,    // Position within module
    @Default(0) int version,
  }) = _StoreShortEntity;
}

/// Tracks a user's downloaded store module (link between user and store)
@freezed
class DownloadedStoreModule with _$DownloadedStoreModule {
  const factory DownloadedStoreModule({
    required String storeModuleId,
    required String userModuleId,     // User's local module ID
    required int downloadedVersion,   // Version at download time
    required DateTime downloadedAt,
    @Default(false) bool updateAvailable, // True if store version > downloaded
  }) = _DownloadedStoreModule;
}
```

### 6.16 Note Feed Scoring (Free Tier)

```dart
/// Client-side scoring state for the free-tier note feed algorithm.
/// No backend calls — runs entirely in Dart on the device.
@freezed
class NoteFeedState with _$NoteFeedState {
  const factory NoteFeedState({
    @Default({}) Map<String, int> skipCounts,    // noteId → skip count
    @Default({}) Map<String, DateTime> lastSeen, // noteId → last displayed
    @Default([]) List<String> readNoteIds,       // Completed notes
    @Default([]) List<String> recentTopics,      // Last 5 shown topics
    @Default(0) double avgReadLengthWords,       // User's avg read length
  }) = _NoteFeedState;
}
```

---

## 7. Database Schema

### 7.1 Firestore Collections

```
firestore/
├── users/{userId}                          # User profile, settings, stats
│   ├── interactions/{interactionId}        # Sub-collection: user interactions (UP-05)
│   ├── bookmarks/{bookmarkId}              # Sub-collection: saved Shorts
│   ├── fsrs_cards/{articleId}              # Sub-collection: spaced repetition state
│   ├── notifications/{notificationId}      # Sub-collection: user notifications
│   └── downloaded_modules/{storeModuleId}  # Sub-collection: store download tracking
│
├── notes/{noteId}                          # Raw ingested media/notes
│   └── chunks/{chunkId}                    # Sub-collection: chunk metadata
│
├── articles/{articleId}                    # Generated Shorts
│
├── modules/{moduleId}                      # Module definitions
│
├── sources/{sourceId}                      # Content sources (RSS, URLs)
│
├── processing_tasks/{taskId}               # Pipeline task tracking
│
├── knowledge_graph/{userId}/
│   ├── concepts/{conceptId}                # KG nodes
│   └── relationships/{relationshipId}      # KG edges
│
├── learning_paths/{pathId}                 # Learning paths
│
├── quizzes/{quizId}                        # Quiz records with scores
│
├── analytics/{userId}/
│   └── periods/{periodId}                  # Aggregated metrics
│
├── app_config/
│   ├── topics                              # Global topic definitions
│   ├── feature_flags                       # Feature flags (MA-06)
│   ├── predefined_sources                  # Curated source catalog (CS-07)
│   └── subscription_plans                  # Available plans + pricing
│
└── store/                                  # Module Store (global, read-only)
    ├── modules/{storeModuleId}             # Pre-made modules by app owner
    │   └── shorts/{storeShortId}           # Sub-collection: module shorts
    └── featured/                           # Featured/promoted modules
```

### 7.2 Firestore Security Rules (SE-03)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // User — owner only
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      match /{subcollection}/{docId} {
        allow read, write: if request.auth.uid == userId;
      }
    }
    // Notes — owner only
    match /notes/{noteId} {
      allow read, write: if request.auth != null
                         && request.auth.uid == resource.data.userId;
      allow create: if request.auth != null
                    && request.auth.uid == request.resource.data.userId;
      match /chunks/{chunkId} {
        allow read: if request.auth.uid ==
          get(/databases/$(database)/documents/notes/$(noteId)).data.userId;
      }
    }
    // Articles — owner only
    match /articles/{articleId} {
      allow read, write: if request.auth != null
                         && request.auth.uid == resource.data.userId;
      allow create: if request.auth != null;
    }
    // Modules, Sources, Processing Tasks — owner only
    match /{collection}/{docId} {
      allow read, write: if collection in ['modules', 'sources', 'processing_tasks']
                         && request.auth != null
                         && request.auth.uid == resource.data.userId;
    }
    // Knowledge Graph — owner only
    match /knowledge_graph/{userId}/{document=**} {
      allow read, write: if request.auth.uid == userId;
    }
    // App config — read-only for authenticated users
    match /app_config/{doc} {
      allow read: if request.auth != null;
      allow write: if false; // Admin SDK only
    }
    // Module Store — read-only for all authenticated users
    match /store/{document=**} {
      allow read: if request.auth != null;
      allow write: if false; // Admin SDK only (app owner uploads)
    }
  }
}
```

### 7.3 ChromaDB Schema

User-scoped collections (SE-03, RQ-06). One collection per user:

```python
# Collection: "user_{userId}_chunks"
{
    "id": "chunk_abc123",
    "embedding": [0.123, -0.456, ...],  # 768-dim gemini-embedding-001
    "document": "The chunk text content...",
    "metadata": {
        "user_id": "user_xyz",
        "note_id": "note_456",
        "source_id": "source_789",
        "section_title": "Introduction to Neural Networks",
        "page_offset": 3,
        "paragraph_offset": 12,
        "token_span": [0, 450],
        "quality_score": 0.92,       # CP-04b
        "content_hash": "sha256:...", # CP-05a
        "topics": ["AI", "neural-networks"],
        "difficulty": 0.6,
        "created_at": "2026-01-15T10:30:00Z",
        "media_type": "text"          # For cross-modal dedup (CP-05d)
    }
}
```

### 7.4 Drift (Local SQLite) Schema

```dart
// Cached Shorts for offline reading (OS-01)
class CachedShorts extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get content => text()();    // Full Markdown
  TextColumn get summary => text()();
  TextColumn get topicsJson => text()(); // JSON-encoded list
  RealColumn get difficulty => real().withDefault(const Constant(0.5))();
  IntColumn get level => integer().withDefault(const Constant(1))();
  TextColumn get prerequisitesJson => text().withDefault(const Constant('[]'))();
  TextColumn get relatedJson => text().withDefault(const Constant('[]'))();
  TextColumn get citationsJson => text().withDefault(const Constant('[]'))();
  TextColumn get promptsJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get cachedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

// Offline interaction queue (OS-04)
class PendingInteractions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get articleId => text()();
  TextColumn get type => text()();
  DateTimeColumn get timestamp => dateTime()();
  RealColumn get timeSpent => real().withDefault(const Constant(0))();
  RealColumn get scrollDepth => real().withDefault(const Constant(0))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
}

// Module cache
class CachedModules extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get shortIdsJson => text()();
  IntColumn get completedShorts => integer().withDefault(const Constant(0))();
  IntColumn get totalShorts => integer().withDefault(const Constant(0))();
  DateTimeColumn get cachedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}
```

---

## 8. State Management — Riverpod Architecture

### 8.1 Conventions

- Use `@riverpod` code generation for all providers
- One `providers.dart` per feature folder
- `keepAlive: true` only for global singletons (auth, database, dio, settings)
- All other providers are auto-disposed when no longer listened to
- Use `AsyncNotifier` for any provider that performs async operations with mutations
- Use `StreamProvider` for real-time Firestore data

### 8.2 Core Providers

```dart
// Firebase providers (keepAlive — global singletons)
@Riverpod(keepAlive: true) FirebaseAuth firebaseAuth(Ref ref) => FirebaseAuth.instance;
@Riverpod(keepAlive: true) FirebaseFirestore firestore(Ref ref) => FirebaseFirestore.instance;
@Riverpod(keepAlive: true) FirebaseStorage firebaseStorage(Ref ref) => FirebaseStorage.instance;

// Dio HTTP client with interceptors (auth token, retry, logging)
@Riverpod(keepAlive: true) Dio dio(Ref ref) { /* ... */ }
@Riverpod(keepAlive: true) ApiClient apiClient(Ref ref) => ApiClient(ref.read(dioProvider));

// Local database (Drift)
@Riverpod(keepAlive: true) AppDatabase appDatabase(Ref ref) => AppDatabase();

// Connectivity stream (OS-03)
@riverpod Stream<bool> connectivity(Ref ref) { /* ... */ }
```

### 8.3 Feature Providers (Key Examples)

```dart
// AUTH — drives routing
@Riverpod(keepAlive: true) Stream<UserEntity?> authStateChanges(Ref ref) { /* ... */ }
@Riverpod(keepAlive: true) class CurrentUser extends _$CurrentUser { /* ... */ }

// SHORTS FEED — real-time from Firestore + local cache fallback
@riverpod Stream<List<ShortEntity>> shortsFeed(Ref ref) { /* ... */ }
@riverpod class CurrentShort extends _$CurrentShort { /* ... */ }
@riverpod Future<NavigationOptions> navigationOptions(Ref ref) { /* KG-11 */ }

// INTERACTIONS — triggers roadmap recalculation (AL-01, UI-09)
@riverpod class InteractionNotifier extends _$InteractionNotifier {
  Future<void> markDone(String articleId, double timeSpent, double scrollDepth) { /* ... */ }
  Future<void> skip(String articleId) { /* ... */ }
  Future<void> bookmark(String articleId) { /* ... */ }
  Future<void> giveFeedback(String articleId, String feedbackType) { /* UI-10 */ }
}

// ENGAGEMENT TRACKING — time + scroll (UI-07, UI-08)
@riverpod class EngagementTracker extends _$EngagementTracker { /* ... */ }

// KNOWLEDGE GRAPH (KG-13)
@riverpod Future<KnowledgeGraphData> knowledgeGraph(Ref ref) { /* ... */ }
@riverpod class NavigationStack extends _$NavigationStack { /* KG-12 */ }

// SEARCH (SD-01–06)
@riverpod class SearchNotifier extends _$SearchNotifier { /* ... */ }

// RAG CHAT (RQ-01–13)
@riverpod class RagChatNotifier extends _$RagChatNotifier { /* ... */ }

// SETTINGS (SP-01–11)
@Riverpod(keepAlive: true) class ThemeModeNotifier extends _$ThemeModeNotifier { /* SP-01 */ }
@Riverpod(keepAlive: true) class FontSizeNotifier extends _$FontSizeNotifier { /* SP-02 */ }

// OFFLINE SYNC (OS-01–06)
@Riverpod(keepAlive: true) class AutoSync extends _$AutoSync { /* OS-04 */ }
@riverpod Stream<int> pendingSyncCount(Ref ref) { /* ... */ }
```

### 8.4 Provider Dependency Graph

```
firebaseAuth ─► authRepository ─► authStateChanges ─► currentUser
                                                           │
              ┌────────────────────────────────────────────┤
              │                    │                        │
        shortsFeed          knowledgeGraph            analytics
              │
        currentShort
              │
    navigationOptions
```

---

## 9. Feature Breakdown

### Feature → Requirement Mapping

| Feature | Req IDs | Core Screens | Key Providers |
|---------|---------|-------------|--------------|
| **Auth** | AP-01–07 | LoginScreen, SignupScreen, ForgotPasswordScreen | authRepository, authStateChanges, currentUser |
| **Onboarding** | ON-01–06 | FeatureShowcase, InterestSelection, SourceSetup, GoalSelection, Proficiency | onboardingNotifier, interestsNotifier |
| **Home** | — | HomeScreen (shell with bottom nav) | bottomNavIndex |
| **Shorts Feed** | SM-01–10, UI-01–12, AL-01–13 | ShortsFeedScreen, ShortDetailScreen | shortsFeed, currentShort, interactionNotifier, engagementTracker |
| **Modules** | MO-01–09 | ModulesListScreen, ModuleDetailScreen, CreateModuleScreen | modulesList, moduleDetail, moduleProgress |
| **Knowledge Graph** | KG-01–17 | KnowledgeGraphScreen | knowledgeGraph, kgNeighbors, navigationStack |
| **Search** | SD-01–06 | SearchScreen | searchNotifier, searchSuggestions |
| **RAG Query** | RQ-01–13 | RagChatScreen, MindMapScreen | ragChatNotifier |
| **Quiz** | RA-01–12 | QuizScreen, QuizResultScreen, SpacedReviewScreen | quizNotifier, fsrsScheduler |
| **Analytics** | AT-01–08 | AnalyticsDashboardScreen, AchievementsScreen | analyticsData, streakData, achievements |
| **Profile** | UP-01–10, AP-03–04 | ProfileScreen, EditProfileScreen | userProfile, topicExpertise |
| **Settings** | SP-01–11 | SettingsScreen, DataManagementScreen | themeMode, fontSize, ttsEnabled |
| **Sources** | CS-01–07, MI-05–09 | SourcesListScreen, SourceDetailScreen, AddSourceScreen | sourcesList, sourceHealth |
| **Notes** | MI-01–13 | NotesListScreen, NoteDetailScreen, CreateNoteScreen, UploadMediaScreen | notesList, processingTasks |
| **Bookmarks** | UI-03 | BookmarksScreen | bookmarksList |
| **Notifications** | NO-01–05 | NotificationsScreen | notificationsList |
| **Offline** | OS-01–06 | (ambient — no dedicated screen) | syncStatus, pendingSyncCount, autoSync |
| **Note Feed (Free)** | — | NoteFeedScreen | noteFeed, noteFeedScorer, noteInteractionNotifier |
| **Subscription** | SUB-01–06 | SubscriptionScreen, PaywallSheet | subscriptionStatus, purchaseNotifier |
| **Module Store** | — | ModuleStoreScreen, StoreModuleDetailScreen | storeModules, downloadNotifier |

### 9.2 Subscription & Monetization Architecture

#### Tier Definitions

| Feature | Free | Premium |
|---------|------|---------|
| **Note Ingestion** (text, URL, file, share) | ✅ Unlimited | ✅ Unlimited |
| **Note Feed** (swipeable raw notes) | ✅ Full access | ✅ Full access |
| **Note Feed Algorithm** (basic scoring) | ✅ Client-side | ✅ Client-side |
| **AI Processing Pipeline** | ❌ | ✅ Full pipeline |
| **Shorts Generation** | ❌ | ✅ Unlimited |
| **Shorts Feed** (AI-generated, horizontal swipe) | ❌ | ✅ Full access |
| **Knowledge Graph** | ❌ | ✅ Visualization + navigation |
| **Adaptive Learning Paths** | ❌ | ✅ Full recommendation engine |
| **RAG / Knowledge Query** | ❌ | ✅ Full RAG pipeline |
| **Quizzes & FSRS Spaced Repetition** | ❌ | ✅ Full assessment |
| **Analytics Dashboard** | Basic (streak + counts) | ✅ Full charts + insights |
| **Module Store** (download pre-made) | ✅ Limited (3 modules) | ✅ Unlimited downloads |
| **Modules** (auto-generated) | ❌ | ✅ Auto + manual |
| **Search** (keyword) | ✅ Basic keyword | ✅ Semantic + hybrid |
| **Offline Caching** | ✅ Notes only | ✅ Notes + Shorts |
| **Content Sources** (RSS, newsletters) | ✅ 3 sources max | ✅ Unlimited |
| **Bookmarks** | ✅ | ✅ |
| **Share Intent** (receive) | ✅ | ✅ |
| **TTS** | ❌ | ✅ |

#### RevenueCat Integration

```
┌──────────────────────────────────────────────────┐
│               PAYMENT FLOW                       │
│                                                  │
│  Flutter App                                     │
│  ┌──────────────┐                               │
│  │ RevenueCat   │                               │
│  │ SDK          │──────► Apple App Store         │
│  │ (purchases_  │──────► Google Play Store       │
│  │  flutter)    │                               │
│  └──────┬───────┘                               │
│         │                                        │
│  ┌──────▼───────┐                               │
│  │ Entitlement  │  RevenueCat handles:           │
│  │ Check        │  - Receipt validation          │
│  │              │  - Subscription lifecycle       │
│  │ "premium"    │  - Trial management            │
│  │ entitlement  │  - Cross-platform sync         │
│  └──────┬───────┘  - Grace periods              │
│         │           - Refund detection            │
│  ┌──────▼───────┐                               │
│  │ Sync to      │  RevenueCat webhook writes     │
│  │ Firestore    │  subscription status to         │
│  │              │  users/{uid}.subscription       │
│  └──────────────┘                               │
└──────────────────────────────────────────────────┘
```

#### Subscription Plans

| Plan | Price | Product ID | Features |
|------|-------|-----------|----------|
| **Free** | $0 | — | Note feed, basic search, 3 sources, 3 store modules |
| **Premium Monthly** | ~$4.99/mo | `geeky_premium_monthly` | Everything |
| **Premium Yearly** | ~$39.99/yr | `geeky_premium_yearly` | Everything (33% discount) |
| **Trial** | 7 days free | — | Full Premium, auto-converts |

#### Feature Gating Pattern

```dart
// Riverpod provider for subscription status
@Riverpod(keepAlive: true)
class SubscriptionNotifier extends _$SubscriptionNotifier {
  @override
  SubscriptionInfo build() {
    // Listen to RevenueCat customer info stream
    _listenToRevenueCat();
    // Also sync from Firestore for offline fallback
    return ref.read(currentUserProvider)?.subscription ?? const SubscriptionInfo();
  }

  bool get isPremium => state.isPremium;
}

// Feature gate widget — used throughout the app
class PremiumGate extends ConsumerWidget {
  final Widget child;          // Shown if premium
  final Widget? fallback;      // Shown if free (optional)
  final bool showPaywall;      // Show paywall sheet on tap

  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(subscriptionNotifierProvider).isPremium;
    if (isPremium) return child;
    if (fallback != null) return fallback!;
    if (showPaywall) return GestureDetector(
      onTap: () => showPaywallSheet(context),
      child: LockedFeatureCard(featureName: '...'),
    );
    return const SizedBox.shrink();
  }
}

// Usage in screens:
PremiumGate(
  showPaywall: true,
  child: ShortsFeedScreen(),          // Premium: full Shorts
  fallback: NoteFeedScreen(),          // Free: raw note cards
)
```

#### Backend Subscription Enforcement

```python
# Backend middleware — checks subscription for premium-only endpoints
async def require_premium(user: User = Depends(get_current_user)):
    if user.subscription.tier != "premium":
        raise HTTPException(
            status_code=403,
            detail="Premium subscription required for this feature"
        )

# Applied to premium-only routes:
@router.post("/pipeline/process", dependencies=[Depends(require_premium)])
@router.post("/rag/query",        dependencies=[Depends(require_premium)])
@router.post("/quiz/generate",    dependencies=[Depends(require_premium)])
@router.get("/kg/graph",          dependencies=[Depends(require_premium)])
```

### 9.3 Free Tier — Note Feed Architecture

The Note Feed is the **core free experience**. Users ingest notes (text, URLs, files, share intent) and view them as **horizontally swipeable cards** — similar to Shorts in layout but showing raw note content without any AI processing.

#### Note Feed vs Shorts Feed

```
┌──────────────────────────────────────────────────────────┐
│  FREE TIER: Note Feed                                    │
│                                                          │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐            │
│  │  Note A   │◄──│  Note B   │──►│  Note C   │           │
│  │           │   │           │   │           │           │
│  │ Raw text  │   │ URL       │   │ PDF text  │           │
│  │ + images  │   │ content   │   │ + images  │           │
│  │           │   │           │   │           │           │
│  │ [Done] [Skip]│ [Done] [Skip]│ [Done] [Skip]│          │
│  └──────────┘   └──────────┘   └──────────┘            │
│                                                          │
│  ◄──── SWIPE LEFT/RIGHT ────►                            │
│  No KG, No AI processing, No learning paths              │
│  Basic algorithm: recency × length × history × retention │
│                                                          │
├──────────────────────────────────────────────────────────┤
│  PREMIUM: Shorts Feed                                    │
│                                                          │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐            │
│  │  Short A  │◄──│  Short B  │──►│  Short C  │           │
│  │           │   │           │   │           │           │
│  │ AI summary│   │ AI summary│   │ AI summary│           │
│  │ + images  │   │ + images  │   │ + images  │           │
│  │ + explore │   │ + explore │   │ + explore │           │
│  │           │   │           │   │           │           │
│  │[Done][Skip]│  │[Deeper][Up]│  │[Done][Skip]│          │
│  │[Share][Save]│ │[Next][Rel] │  │[Share][Save]│         │
│  └──────────┘   └──────────┘   └──────────┘            │
│                                                          │
│  ◄──── SWIPE LEFT/RIGHT ────►                            │
│  Full KG navigation, AI-powered, adaptive paths          │
│  Multi-factor scoring: relevance × capability × novelty  │
└──────────────────────────────────────────────────────────┘
```

#### Client-Side Note Feed Scoring Algorithm

This runs entirely in **Dart on the device** — no backend calls, no AI, no embeddings. The algorithm scores each note and sorts the feed.

```dart
class NoteFeedScorer {
  /// Score a note for feed ordering. Higher = shown first.
  double scoreNote(NoteEntity note, NoteFeedState state, DateTime now) {
    double score = 0.0;

    // ── RECENCY (newer notes prioritized) ──
    final ageHours = now.difference(note.createdAt).inHours;
    score += _recencyBoost(ageHours);
    // Today: +3.0, This week: +2.0, This month: +1.0, Older: +0.5

    // ── READ STATUS (unread gets significant boost) ──
    if (!state.readNoteIds.contains(note.id)) {
      score += 4.0;
    }

    // ── LENGTH PREFERENCE (match user's avg reading length) ──
    // If user typically reads 300-word notes, prioritize similar length
    if (state.avgReadLengthWords > 0) {
      final diff = (note.wordCount - state.avgReadLengthWords).abs();
      score += 1.0 / (1.0 + diff / 200.0); // Gaussian-like decay
    }

    // ── SKIP PENALTY (frequently skipped = deprioritize) ──
    final skips = state.skipCounts[note.id] ?? 0;
    score -= skips * 0.7;

    // ── RETENTION RESURFACING (old notes resurface after interval) ──
    final lastSeen = state.lastSeen[note.id];
    if (lastSeen != null && state.readNoteIds.contains(note.id)) {
      final daysSince = now.difference(lastSeen).inDays;
      // Fibonacci-like intervals: 1, 3, 7, 14, 30 days
      if (_isDueForResurface(daysSince)) score += 2.5;
    }

    // ── TOPIC DIVERSITY (penalize if same topic shown recently) ──
    if (note.metadata['primaryTopic'] != null &&
        state.recentTopics.contains(note.metadata['primaryTopic'])) {
      score -= 1.5;
    }

    // ── TIME-OF-DAY CONTEXT ──
    final hour = now.hour;
    if (hour >= 22 || hour < 7) {
      // Late night/early morning: prefer shorter notes
      score += note.wordCount < 200 ? 1.0 : -0.5;
    }

    // ── MEDIA BONUS (notes with images are more engaging) ──
    if (note.mediaAssets.isNotEmpty) score += 0.5;

    return score;
  }

  bool _isDueForResurface(int daysSince) {
    const intervals = [1, 3, 7, 14, 30, 60, 90];
    return intervals.any((i) => daysSince >= i && daysSince < i + 2);
  }
}
```

#### Note Feed Providers

```dart
// Client-side sorted note feed for free tier
@riverpod
class NoteFeedNotifier extends _$NoteFeedNotifier {
  @override
  Future<List<NoteEntity>> build() async {
    final userId = ref.watch(currentUserProvider)?.id;
    if (userId == null) return [];

    final notes = await ref.watch(notesRepositoryProvider).getAllNotes(userId);
    final feedState = await ref.watch(noteFeedStateProvider.future);
    final scorer = NoteFeedScorer();
    final now = DateTime.now();

    // Score and sort notes — entirely client-side
    final scored = notes.map((n) => (n, scorer.scoreNote(n, feedState, now))).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));

    return scored.map((s) => s.$1).toList();
  }
}

// Persisted feed state in Drift (survives app restarts)
@riverpod
Future<NoteFeedState> noteFeedState(Ref ref) async {
  final dao = ref.read(appDatabaseProvider).noteFeedDao;
  return dao.loadState();
}
```

### 9.4 Module Store Architecture

#### Overview

The Module Store provides pre-made, downloadable learning modules created by the app owner. Users browse, preview, and download modules which get copied into their personal collection. Downloaded modules integrate with the user's existing KG and recommendation engine (if premium).

```
┌──────────────────────────────────────────────────────────┐
│                    MODULE STORE FLOW                      │
│                                                          │
│  ┌─────────────────┐                                    │
│  │ Module Store     │  Global Firestore: store/modules/  │
│  │ Screen           │  Read-only for users               │
│  │                  │  Written by Admin SDK (app owner)   │
│  │ - Browse catalog │                                    │
│  │ - Filter by topic│                                    │
│  │ - Preview module │                                    │
│  └────────┬─────────┘                                    │
│           │ User taps "Download"                         │
│           ▼                                              │
│  ┌─────────────────┐                                    │
│  │ Download Flow    │                                    │
│  │                  │  1. Copy StoreShorts → user's       │
│  │                  │     articles collection              │
│  │                  │  2. Create Module in user's          │
│  │                  │     modules collection               │
│  │                  │  3. Track download in user's         │
│  │                  │     downloaded_modules sub-collection│
│  │                  │  4. [Premium] Add to KG + roadmap   │
│  └────────┬─────────┘                                    │
│           │                                              │
│           ▼                                              │
│  ┌─────────────────┐                                    │
│  │ User's Library   │  Now appears in:                   │
│  │                  │  - Modules list                     │
│  │                  │  - Shorts feed (if premium)         │
│  │                  │  - KG visualization (if premium)    │
│  │                  │  - Note feed (if free — as cards)   │
│  └─────────────────┘                                    │
│                                                          │
│  ┌─────────────────┐                                    │
│  │ Update Detection │  Cloud Function checks weekly:      │
│  │                  │  store module version > downloaded   │
│  │                  │  → Set updateAvailable = true        │
│  │                  │  → User sees "Update" badge          │
│  └─────────────────┘                                    │
└──────────────────────────────────────────────────────────┘
```

#### Future Marketplace Extension

The store is designed with marketplace expansion in mind:

```
Phase 1 (Current):  App owner creates modules → users download
Phase 2 (Future):   Verified creators can publish → review process → marketplace
Phase 3 (Future):   Paid modules → revenue share with creators
```

Architectural preparation:
- `StoreModuleEntity.createdBy` already supports multiple creators
- `store/modules` collection can be partitioned by creator
- Review/approval workflow can be added via Cloud Functions
- Payment splits handled by RevenueCat's Paywalls

#### Store Providers

```dart
// Browse store modules (paginated)
@riverpod
Future<List<StoreModuleEntity>> storeModules(Ref ref, {String? topicFilter}) async {
  final firestore = ref.read(firestoreProvider);
  var query = firestore.collection('store').doc('modules').collection('modules')
    .orderBy('downloadCount', descending: true);
  if (topicFilter != null) {
    query = query.where('topics', arrayContains: topicFilter);
  }
  // ... fetch and parse
}

// Download a store module to user's collection
@riverpod
class DownloadModuleNotifier extends _$DownloadModuleNotifier {
  @override
  FutureOr<void> build() {}

  Future<void> download(StoreModuleEntity storeModule) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userId = ref.read(currentUserProvider)!.id;
      final isPremium = ref.read(subscriptionNotifierProvider).isPremium;

      // Check free tier limit (3 max)
      if (!isPremium) {
        final downloaded = await ref.read(downloadedModuleCountProvider.future);
        if (downloaded >= 3) throw DownloadLimitException();
      }

      // 1. Fetch all shorts from store module
      final storeShorts = await _fetchStoreShorts(storeModule.id);

      // 2. Copy shorts to user's articles collection
      final userShortIds = await _copyToUserArticles(userId, storeShorts);

      // 3. Create module in user's collection
      final userModule = ModuleEntity(
        id: const Uuid().v4(),
        userId: userId,
        name: storeModule.name,
        description: storeModule.description,
        topics: storeModule.topics,
        shortIds: userShortIds,
        type: 'store',
        progress: ModuleProgress(totalShorts: userShortIds.length),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await ref.read(modulesRepositoryProvider).createModule(userModule);

      // 4. Track download
      await _trackDownload(userId, storeModule.id, userModule.id, storeModule.version);

      // 5. [Premium] Integrate with KG + recommendation engine
      if (isPremium) {
        await ref.read(apiClientProvider).integrateStoreModule(userModule.id);
      }

      // Invalidate affected providers
      ref.invalidate(modulesListProvider);
      ref.invalidate(shortsFeedProvider);
    });
  }
}
```

---

## 10. Screens & Navigation

### 10.1 Screen Inventory (All Screens)

| # | Screen | Route | Auth | Req IDs | Description |
|---|--------|-------|------|---------|-------------|
| 1 | **SplashScreen** | `/` | No | — | App logo, Firebase init, route to auth/home |
| 2 | **LoginScreen** | `/login` | No | AP-01, AP-02 | Email/password + Google Sign-In |
| 3 | **SignupScreen** | `/signup` | No | AP-01, AP-02 | Registration form |
| 4 | **ForgotPasswordScreen** | `/forgot-password` | No | AP-01 | Password reset via email |
| 5 | **FeatureShowcaseScreen** | `/onboarding` | Yes | ON-01 | Swipeable intro pages |
| 6 | **InterestSelectionScreen** | `/onboarding/interests` | Yes | ON-02 | Searchable topic chips |
| 7 | **SourceSetupScreen** | `/onboarding/sources` | Yes | ON-03 | URL input + predefined sources |
| 8 | **GoalSelectionScreen** | `/onboarding/goals` | Yes | ON-04 | Learning goal cards |
| 9 | **ProficiencyScreen** | `/onboarding/proficiency` | Yes | ON-05 | Per-topic level sliders |
| 10 | **HomeScreen** | `/home` | Yes | — | Shell with BottomNavigationBar |
| 11 | **NoteFeedScreen** | `/home/feed` | Yes | — | **Free tier**: Horizontal swipe cards of raw notes |
| 12 | **ShortsFeedScreen** | `/home/shorts` | Yes (Premium) | SM-01–02, UI-11 | **Premium**: Horizontal swipe cards of AI Shorts |
| 13 | **ShortDetailScreen** | `/home/shorts/:id` | Yes (Premium) | SM-09, UI-01–08 | Full reader + actions bar + KG navigation |
| 14 | **ModulesListScreen** | `/home/modules` | Yes | MO-01 | Grid/list of Modules |
| 14 | **ModuleDetailScreen** | `/home/modules/:id` | Yes | MO-07, MO-08 | Module contents + progress |
| 15 | **CreateModuleScreen** | `/home/modules/create` | Yes | MO-03 | Manual module creation |
| 16 | **KnowledgeGraphScreen** | `/home/graph` | Yes | KG-13, AT-06 | Interactive graph visualization |
| 17 | **SearchScreen** | `/search` | Yes | SD-01–06 | Search bar + filters + results |
| 18 | **RagChatScreen** | `/rag` | Yes | RQ-01, RQ-05 | Chat-style Q&A interface |
| 19 | **MindMapScreen** | `/rag/mindmap` | Yes | RQ-13 | Hierarchical mind map view |
| 20 | **QuizScreen** | `/quiz/:articleId` | Yes | RA-02, RA-08 | Question cards with answers |
| 21 | **QuizResultScreen** | `/quiz/:id/result` | Yes | RA-03 | Score + concept breakdown |
| 22 | **SpacedReviewScreen** | `/review` | Yes | RA-01 | Due cards for spaced repetition |
| 23 | **AnalyticsDashboardScreen** | `/analytics` | Yes | AT-05 | Charts + stats overview |
| 24 | **AchievementsScreen** | `/analytics/achievements` | Yes | AT-08 | Badges + milestones |
| 25 | **ProfileScreen** | `/profile` | Yes | AP-03, UP-01 | User info + expertise radar |
| 26 | **EditProfileScreen** | `/profile/edit` | Yes | AP-04, UP-08 | Edit interests, goals, mode |
| 27 | **SettingsScreen** | `/settings` | Yes | SP-01–07 | Theme, font, TTS, notifications |
| 28 | **DataManagementScreen** | `/settings/data` | Yes | SP-08–10 | Export, import, cache, delete |
| 29 | **SourcesListScreen** | `/sources` | Yes | CS-01 | Source cards with status |
| 30 | **SourceDetailScreen** | `/sources/:id` | Yes | CS-03–04 | Stats + health + config |
| 31 | **AddSourceScreen** | `/sources/add` | Yes | CS-01, CS-07 | URL input + predefined catalog |
| 32 | **NotesListScreen** | `/notes` | Yes | MI-10 | All ingested notes |
| 33 | **NoteDetailScreen** | `/notes/:id` | Yes | MI-13 | Source summary + derived Shorts |
| 34 | **CreateNoteScreen** | `/notes/create` | Yes | MI-03 | Text input |
| 35 | **UploadMediaScreen** | `/notes/upload` | Yes | MI-02 | File picker + upload |
| 36 | **BookmarksScreen** | `/bookmarks` | Yes | UI-03 | Saved Shorts list |
| 37 | **NotificationsScreen** | `/notifications` | Yes | NO-01–05 | Notification list |
| 38 | **SubscriptionScreen** | `/subscription` | Yes | SUB-01–06 | Plans, pricing, purchase |
| 39 | **ModuleStoreScreen** | `/store` | Yes | — | Browse pre-made modules |
| 40 | **StoreModuleDetailScreen** | `/store/:id` | Yes | — | Preview + download |

### 10.2 Navigation Architecture (GoRouter)

```dart
// lib/src/routing/app_router.dart
@riverpod
GoRouter appRouter(Ref ref) {
  final authState = ref.watch(authStateChangesProvider);
  final hasCompletedOnboarding = ref.watch(hasCompletedOnboardingProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isOnAuthPage = state.matchedLocation.startsWith('/login') ||
                           state.matchedLocation.startsWith('/signup');
      final isOnOnboarding = state.matchedLocation.startsWith('/onboarding');

      // Not logged in → redirect to login
      if (!isLoggedIn && !isOnAuthPage) return '/login';
      // Logged in but on auth page → redirect to home
      if (isLoggedIn && isOnAuthPage) {
        return hasCompletedOnboarding ? '/home/feed' : '/onboarding';
      }
      return null; // No redirect
    },
    routes: [
      // Auth routes (no shell)
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),

      // Onboarding flow (no shell)
      GoRoute(path: '/onboarding', builder: (_, __) => const FeatureShowcaseScreen()),
      GoRoute(path: '/onboarding/interests', builder: (_, __) => const InterestSelectionScreen()),
      GoRoute(path: '/onboarding/sources', builder: (_, __) => const SourceSetupScreen()),
      GoRoute(path: '/onboarding/goals', builder: (_, __) => const GoalSelectionScreen()),
      GoRoute(path: '/onboarding/proficiency', builder: (_, __) => const ProficiencyScreen()),

      // Main app with bottom nav shell
      ShellRoute(
        builder: (_, __, child) => HomeScreen(child: child),
        routes: [
          // Feed tab — shows NoteFeed (free) or ShortsFeed (premium)
          GoRoute(
            path: '/home/feed',
            builder: (_, __) {
              // PremiumGate inside the screen decides which feed to show
              return const AdaptiveFeedScreen();
            },
          ),
          GoRoute(
            path: '/home/shorts',
            builder: (_, __) => const ShortsFeedScreen(), // Premium only
            routes: [
              GoRoute(path: ':id', builder: (_, state) => ShortDetailScreen(
                shortId: state.pathParameters['id']!,
              )),
            ],
          ),
          GoRoute(
            path: '/home/modules',
            builder: (_, __) => const ModulesListScreen(),
            routes: [
              GoRoute(path: 'create', builder: (_, __) => const CreateModuleScreen()),
              GoRoute(path: ':id', builder: (_, state) => ModuleDetailScreen(
                moduleId: state.pathParameters['id']!,
              )),
            ],
          ),
          GoRoute(path: '/home/graph', builder: (_, __) => const KnowledgeGraphScreen()),
          GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),

      // Top-level routes (full-screen, no bottom nav)
      GoRoute(path: '/rag', builder: (_, __) => const RagChatScreen()),
      GoRoute(path: '/rag/mindmap', builder: (_, __) => const MindMapScreen()),
      GoRoute(path: '/quiz/:articleId', builder: (_, state) => QuizScreen(
        articleId: state.pathParameters['articleId']!,
      )),
      GoRoute(path: '/review', builder: (_, __) => const SpacedReviewScreen()),
      GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsDashboardScreen()),
      GoRoute(path: '/analytics/achievements', builder: (_, __) => const AchievementsScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/settings/data', builder: (_, __) => const DataManagementScreen()),
      GoRoute(path: '/sources', builder: (_, __) => const SourcesListScreen()),
      GoRoute(path: '/sources/add', builder: (_, __) => const AddSourceScreen()),
      GoRoute(path: '/sources/:id', builder: (_, state) => SourceDetailScreen(
        sourceId: state.pathParameters['id']!,
      )),
      GoRoute(path: '/notes', builder: (_, __) => const NotesListScreen()),
      GoRoute(path: '/notes/create', builder: (_, __) => const CreateNoteScreen()),
      GoRoute(path: '/notes/upload', builder: (_, __) => const UploadMediaScreen()),
      GoRoute(path: '/notes/:id', builder: (_, state) => NoteDetailScreen(
        noteId: state.pathParameters['id']!,
      )),
      GoRoute(path: '/bookmarks', builder: (_, __) => const BookmarksScreen()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/profile/edit', builder: (_, __) => const EditProfileScreen()),
      GoRoute(path: '/subscription', builder: (_, __) => const SubscriptionScreen()),
      GoRoute(path: '/store', builder: (_, __) => const ModuleStoreScreen()),
      GoRoute(path: '/store/:id', builder: (_, state) => StoreModuleDetailScreen(
        storeModuleId: state.pathParameters['id']!,
      )),
    ],
  );
}
```

### 10.3 Bottom Navigation Bar

```
┌────────────────────────────────────────────┐
│              Bottom Nav Bar                │
├──────┬──────┬──────┬──────┬───────────────┤
│ Feed │Modules│Graph │Search│  Profile      │
│  📄  │  📚  │  🕸  │  🔍 │    👤         │
└──────┴──────┴──────┴──────┴───────────────┘
```

5 tabs: **Feed** (NoteFeedScreen *or* ShortsFeedScreen based on tier), **Modules** (ModulesListScreen), **Graph** (KnowledgeGraphScreen — premium lock), **Search** (SearchScreen), **Profile** (ProfileScreen).

### 10.4 Horizontal Swipe Mechanic (Both Feeds)

Both the Note Feed (free) and Shorts Feed (premium) use **horizontal left/right swipe** via a `PageView` with `scrollDirection: Axis.horizontal`:

```dart
// Shared swipeable card infrastructure
class HorizontalCardFeed<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(T item) cardBuilder;
  final void Function(int index) onPageChanged;

  Widget build(BuildContext context) {
    return PageView.builder(
      scrollDirection: Axis.horizontal, // ◄── LEFT/RIGHT swipe
      itemCount: items.length,
      onPageChanged: onPageChanged,
      itemBuilder: (_, index) => cardBuilder(items[index]),
    );
  }
}

// Free tier: NoteFeedScreen
HorizontalCardFeed<NoteEntity>(
  items: notes,
  cardBuilder: (note) => NoteCard(note: note), // Raw content card
  onPageChanged: (i) => noteFeedNotifier.markSeen(notes[i].id),
)

// Premium: ShortsFeedScreen
HorizontalCardFeed<ShortEntity>(
  items: shorts,
  cardBuilder: (short) => ShortCard(short: short), // AI-generated card
  onPageChanged: (i) => engagementTracker.startTracking(),
)
```

**Swipe gestures:**
- **Swipe left** → Next card (advance in feed)
- **Swipe right** → Previous card (go back)
- **Action buttons** on each card: Done, Skip, Bookmark, Share (both tiers)
- **Premium-only buttons**: Dive Deeper, Go Up, Related, Next (KG navigation)

### 10.4 Screen Flow Diagram

```
                    ┌─────────┐
                    │ Splash  │
                    └────┬────┘
                         │
              ┌──────────┼──────────┐
              │          │          │
         ┌────▼────┐  ┌──▼──┐  ┌───▼────┐
         │  Login  │  │Sign │  │Onboard │
         │         │  │ Up  │  │  Flow  │
         └────┬────┘  └──┬──┘  └───┬────┘
              └──────────┼─────────┘
                         │
                    ┌────▼────┐
                    │  Home   │ ◄── Bottom Nav Shell
                    │ (Feed)  │
                    └────┬────┘
                         │
         ┌───────┬───────┼───────┬───────┐
         │       │       │       │       │
    ┌────▼──┐ ┌──▼───┐ ┌─▼──┐ ┌─▼────┐ ┌▼──────┐
    │ Short │ │Module│ │ KG │ │Search│ │Profile│
    │Detail │ │Detail│ │Viz │ │      │ │      │
    └───┬───┘ └──────┘ └────┘ └──────┘ └──────┘
        │
  ┌─────┼─────┬──────────┐
  │     │     │          │
┌─▼──┐ ┌▼──┐ ┌▼────┐ ┌──▼──┐
│Quiz│ │RAG│ │Notes│ │Book │
│    │ │   │ │     │ │marks│
└────┘ └───┘ └─────┘ └─────┘
```

---

## 11. Content Processing Pipeline

### 11.1 Pipeline Architecture

The pipeline runs entirely on the **Python backend** (Cloud Run). It is triggered by Firestore Cloud Functions on note creation/update events.

```
┌─────────────────────────────────────────────────────────────────┐
│                    CONTENT PROCESSING PIPELINE                  │
│                                                                 │
│  ┌─────────┐   ┌──────────┐   ┌─────────┐   ┌──────────────┐  │
│  │ EXTRACT  │──►│ CHUNK    │──►│ DEDUP   │──►│ EMBED        │  │
│  │ CP-01–02 │   │ CP-03–04a│   │CP-05a–d │   │ CP-04, CP-04b│  │
│  └─────────┘   └──────────┘   └─────────┘   └──────┬───────┘  │
│                                                      │          │
│  ┌─────────────────────────────────────────────────┐ │          │
│  │                      │                          │ │          │
│  │  ┌──────────┐  ┌─────▼────┐  ┌──────────────┐  │ │          │
│  │  │ TAG      │  │SUMMARIZE │  │ STORE        │◄─┘ │          │
│  │  │CP-09–10  │  │ CP-07–08 │  │ ChromaDB     │    │          │
│  │  └────┬─────┘  └────┬─────┘  └──────────────┘    │          │
│  │       │              │                            │          │
│  │  ┌────▼──────────────▼─────┐                      │          │
│  │  │ GENERATE SHORT          │                      │          │
│  │  │ CP-07, CP-11, CP-13     │                      │          │
│  │  │ + NER + exploration Q's  │                      │          │
│  │  └─────────┬───────────────┘                      │          │
│  │            │                                      │          │
│  │  ┌─────────▼───────────┐   ┌──────────────────┐   │          │
│  │  │ UPDATE KG           │   │ UPDATE MODULES   │   │          │
│  │  │ KG-01, KG-10, KG-17│   │ MO-04, MO-05     │   │          │
│  │  └─────────┬───────────┘   └──────────────────┘   │          │
│  │            │                                      │          │
│  │  ┌─────────▼───────────┐                          │          │
│  │  │ RECALC ROADMAP      │                          │          │
│  │  │ AL-01, SYS-04       │                          │          │
│  │  └─────────────────────┘                          │          │
│  └───────────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

### 11.2 Pipeline Steps (Detailed)

**Step 1 — Extraction (CP-01, CP-02)**
```
Input: NoteEntity (type, content/mediaUrl/sourceUrl)
├── TEXT     → Direct pass-through
├── IMAGE   → Gemini Vision API (OCR + description)
├── AUDIO   → Google Cloud Speech-to-Text
├── LINK    → readability-lxml extract article → BeautifulSoup parse HTML
├── VIDEO   → Extract audio track → STT + frame extraction → Gemini Vision
├── FILE    → PyMuPDF (PDF) / python-docx (DOCX) / openpyxl (XLSX)
│
├── IMAGE ASSET EXTRACTION (all types):
│   For any note type, extract embedded images/diagrams/charts:
│   ├── PDF  → extract embedded images via PyMuPDF
│   ├── LINK → extract <img> tags from HTML
│   ├── Note with mixed media → separate image assets
│   For each image asset:
│   ├── Upload to Cloud Storage (if not already there)
│   ├── Gemini Vision → generate description + alt text
│   ├── Store as NoteMedia in note.mediaAssets[]
│   └── Tag with position index (order within the note)
│
Output: Unified text document + metadata + List[NoteMedia]
```

**Step 2 — Chunking (CP-03, CP-04a)**
```
Input: Unified text
├── 1. Split at structural boundaries (headings, section breaks)
├── 2. If no structure → split at paragraph boundaries
├── 3. If paragraph > ~1000 words → semantic change-point detection
│       (sliding window cosine distance on sentence embeddings)
├── 4. Final fallback → sentence boundary split (~200-word overlap)
├── Constraints: Never split inside code blocks, formulas, entities, table rows
└── Validation: Compute intra-chunk embedding variance → re-split if too high
Output: List[Chunk] (text, position metadata)
```

**Step 3 — Deduplication (CP-05a–d, CP-19, CP-20, CP-21)**
```
Input: List[Chunk]
For each chunk:
├── Canonicalize (CP-20): NFC normalize → lowercase → collapse whitespace → strip boilerplate
├── Bloom filter fast screen (CP-19): Quick reject for streaming ingestion
├── Stage 1 — Exact (CP-05a): SHA-256(canonicalized text) → lookup → discard if match
├── Stage 2 — Near-dup (CP-05b): MinHash/LSH (Jaccard ≥ 0.9) → flag for merge
├── Stage 3 — Semantic (CP-05c): Embed → ChromaDB query → cosine ≥ 0.85 → flag
├── Stage 4 — Cross-modal (CP-05d): Compare embeddings across media types
├── Soft dedup (CP-21): Near/semantic dups → link to canonical, downweight; do NOT hard delete
├── Log decision (CP-18): stage, method, matched ID, similarity, outcome
Output: Novel chunks (deduplicated) + dedup audit log
```

**Step 4 — Embedding + Storage (CP-04, CP-04b)**
```
Input: Novel chunks
├── Generate embedding: gemini-embedding-001 (768 dims)
├── Attach metadata (CP-04b): source_id, section_title, page_offset,
│   paragraph_offset, token_span, quality_score, content_hash, topics
├── Store in ChromaDB: user-scoped collection
Output: Embedded chunks in vector store
```

**Step 5 — Short Generation (CP-07, CP-08, CP-09–11, CP-13, CP-15, CP-24)**
```
Input: Novel chunk + source NoteEntity (with mediaAssets)
├── Summarize (CP-07): Gemini → 150–250 word summary (1-min read)
├── Uniqueness check (CP-08): Semantic similarity vs existing Shorts
├── Topic tagging (CP-09): Extract topics via classifier/keywords
├── Difficulty scoring (CP-10): 0.0–1.0 scale
├── NER extraction (CP-13): spaCy → entities for KG
├── Exploration prompts (CP-11): Gemini → 5–10 follow-up questions
├── Conflict detection (CP-16): Flag conflicting facts across sources
├── Anti-density (CP-17): Per-source quotas, inverse-frequency weighting
├── Factuality check (CP-15): Retrieval grounding + consistency check
├── Output dedup (CP-24): Coverage constraints in generation prompt
│
├── IMAGE RELEVANCE ANALYSIS:
│   For each image in source note's mediaAssets[]:
│   ├── Compare image description (from Gemini Vision) with Short content
│   ├── Compute relevance score (cosine similarity of descriptions)
│   ├── If relevanceScore ≥ 0.6 → attach to Short as ShortMedia
│   ├── Images are NOT re-uploaded — same Cloud Storage URL is reused
│   └── Embed in Markdown content as ![altText](storageUrl)
│   Result: Short.media[] populated with relevant source images
│
Output: ShortEntity (with media[]) stored in Firestore articles collection
```

**Step 6 — Knowledge Graph Update (KG-01, KG-10, KG-17, CP-22)**
```
Input: New ShortEntity + NER entities + concepts
├── Create/update concept nodes
├── Determine hierarchy level (KG-02)
├── Create edges: prerequisite, related, deeper, broader, part-of, example-of
├── Generate dynamic edges (KG-17): k-NN by embedding distance, co-citation
├── Update concept inventory (CP-22): cluster embeddings → label → score
Output: Updated Knowledge Graph in Firestore
```

**Step 7 — Recommendation Refresh (AL-01, SYS-04)**
```
Input: Updated KG + user profile
├── Re-score all unread Shorts: relevance (40%) + capability (30%) + novelty (30%)
├── Update recommendedArticleId in user document
Output: Updated learning roadmap
```

### 11.3 Source Auto-Summary (MI-13, SYS-20)

When a new source is ingested, the pipeline also generates:
- Concise source summary
- Key topics/concepts list
- 3–5 suggested exploration questions

These are stored alongside the note and displayed on the source detail view.

### 11.4 Lifecycle Cascade Matrix

Every entity change (create, update, delete) ripples through the system. This matrix documents **every cascade** to ensure no orphaned data or stale references.

#### Note Lifecycle

```
NOTE CREATED (MI-01–13)
  ├── [Premium] Cloud Function triggers → pipeline processes note (SYS-01)
  ├── [Free] Note appears in Note Feed immediately (client-side scoring)
  ├── Note stored in Firestore notes/ collection
  └── ProcessingTask created (LM-08): status = pending

NOTE UPDATED (LM-01)
  ├── [Premium] Re-triggers pipeline (SYS-08):
  │   ├── Delete old chunks from ChromaDB
  │   ├── Re-extract, re-chunk, re-dedup, re-embed
  │   ├── Regenerate affected Shorts (content + metadata)
  │   ├── Update KG edges for affected concepts
  │   ├── Update affected Modules (recalc metadata)
  │   └── Recalculate recommendation roadmap
  ├── [Free] Note Feed re-scores automatically (client-side)
  ├── Note.updatedAt refreshed
  └── ProcessingTask created: status = pending

NOTE DELETED (LM-02, LM-03)
  ├── [Premium] Cascade (SYS-09):
  │   ├── Delete chunks from ChromaDB (by note_id filter)
  │   ├── Delete Shorts that ONLY cite this note (no other sources)
  │   │   └── For each deleted Short:
  │   │       ├── Remove from KG (delete concept if orphaned)
  │   │       ├── Remove from Modules (update shortIds[])
  │   │       ├── Remove FSRS cards
  │   │       ├── Preserve user interaction history (for analytics)
  │   │       └── Recalculate module metadata (MO-08)
  │   ├── Update Shorts that cite this note + OTHER notes
  │   │   └── Remove citations to deleted note, keep Short alive
  │   ├── Delete NoteMedia assets from Cloud Storage
  │   │   └── UNLESS same URL is referenced by another note/Short
  │   └── Recalculate recommendation roadmap
  ├── [Free] Note removed from feed, feed re-scores
  ├── Note doc deleted from Firestore
  └── ProcessingTask created: status = pending (for cleanup)
```

#### Short Lifecycle

```
SHORT CREATED (CP-07, SYS-01)
  ├── KG updated: new concept nodes + edges (KG-10)
  ├── Affected Modules updated: shortIds[] + metadata (MO-04)
  ├── FSRS card created: state = new
  ├── Recommendation roadmap recalculated
  └── [If from store] Marked with sourceType = 'store'

SHORT UPDATED (SM-03, SYS-08)
  ├── Content regenerated from updated source chunks
  ├── KG edges re-evaluated (relationships may change)
  ├── Module metadata recalculated (MO-05)
  ├── Short.version incremented (SM-10)
  ├── FSRS card preserved (don't reset review schedule)
  ├── Engagement metrics preserved
  └── Recommendation roadmap recalculated

SHORT MERGED (SM-04, SYS-07, LM-05)
  ├── Duplicate Short → merged into canonical Short
  ├── Citations consolidated (both source note refs preserved)
  ├── User interactions transferred: if user completed EITHER → canonical = completed
  ├── KG: merged Short's edges transferred to canonical
  ├── Modules: replace merged Short ID with canonical ID
  ├── FSRS: keep the card with best retention metrics
  ├── Merged Short doc deleted
  └── Recommendation roadmap recalculated

SHORT DELETED (SM-05, SYS-09)
  ├── KG: remove concept node IF no other Shorts reference it
  │   └── Remove orphaned edges
  ├── Modules: remove from shortIds[], recalculate metadata
  ├── FSRS card deleted
  ├── Bookmarks referencing this Short: mark as "content removed"
  ├── Preserve interaction history for analytics
  └── Recommendation roadmap recalculated
```

#### Module Lifecycle

```
MODULE CREATED (MO-02, MO-03)
  ├── Auto-created: topic clustering (CP-22) populates shortIds[]
  ├── Manual: user selects Shorts or specifies topic
  ├── [From store] Copied from store module, tracked in downloaded_modules/
  └── Module metadata calculated: topics, difficulty, estimated time

MODULE UPDATED (MO-04, MO-05, LM-06)
  ├── New Short generated in module's topic scope → auto-added (MO-04)
  ├── Short within module updated/merged/deleted → shortIds[] adjusted (MO-05)
  ├── Module metadata recalculated: topic coverage, difficulty, progress, time
  ├── [From store] updateAvailable flag set when store version increments
  └── Adaptive rules re-evaluated (MO-09)

MODULE DELETED (MO-06)
  ├── Module doc deleted
  ├── Constituent Shorts are NOT deleted (preserved in user's collection)
  ├── If store module → downloaded_modules/ tracking record deleted
  └── KG and recommendations unaffected (Shorts still exist)
```

#### Store Module Lifecycle

```
STORE MODULE PUBLISHED (app owner)
  ├── Module + Shorts written to store/ collection via Admin SDK
  ├── Appears in ModuleStoreScreen for all users
  └── Featured modules updated if applicable

STORE MODULE UPDATED (app owner)
  ├── store/modules/{id}.version incremented
  ├── Cloud Function scans all users' downloaded_modules/
  │   └── Sets updateAvailable = true where downloadedVersion < newVersion
  ├── User sees "Update available" badge on module card
  └── On user tap "Update":
      ├── Diff new vs old: add new Shorts, update changed Shorts, remove deleted
      ├── Preserve user's progress (completed Shorts stay completed)
      ├── downloadedVersion updated to new version
      └── [Premium] KG + roadmap recalculated
```

#### Image Asset Lifecycle

```
IMAGE UPLOADED (during note ingestion)
  ├── Stored in Cloud Storage: users/{uid}/media/{imageId}
  ├── Referenced by NoteMedia in note.mediaAssets[]
  └── If reused in Short → also referenced by ShortMedia in short.media[]

IMAGE DELETED (note deletion cascade)
  ├── Check if any OTHER notes or Shorts reference same storageUrl
  ├── If no references → delete from Cloud Storage
  ├── If still referenced → keep (shared resource)
  └── Remove NoteMedia/ShortMedia references from deleted entities
```

---

## 12. Knowledge Graph Architecture

### 12.1 Graph Model

```
Concepts (Nodes)                    Relationships (Edges)
┌─────────────────┐                ┌──────────────────────┐
│ id              │                │ id                   │
│ name            │                │ sourceId             │
│ description     │                │ targetId             │
│ level (1/2/3+)  │────────────────│ type                 │
│ aliases         │                │   prerequisite (DAG) │
│ articleIds      │                │   related (cyclic OK)│
│ importanceScore │                │   part_of            │
│ createdAt       │                │   deeper             │
│ lastUpdatedAt   │                │   broader            │
│                 │                │   example_of         │
│                 │                │ strength (0.0–1.0)   │
│                 │                │ isDynamic            │
│                 │                │ createdAt            │
└─────────────────┘                └──────────────────────┘
```

### 12.2 Hierarchy Levels (KG-02)

```
Level 1: ARTIFICIAL INTELLIGENCE
           ├── Level 2: Machine Learning
           │     ├── Level 3: Neural Networks
           │     │     ├── Level 3+: Backpropagation
           │     │     └── Level 3+: Activation Functions
           │     ├── Level 3: Decision Trees
           │     └── Level 3: SVMs
           ├── Level 2: Natural Language Processing
           │     ├── Level 3: Transformers
           │     └── Level 3: Word Embeddings
           └── Level 2: Computer Vision
```

### 12.3 Navigation Engine (KG-03–07, KG-11–12, KG-14)

The navigation engine on the backend determines available navigation options from any Short:

```python
# Backend: knowledge_graph/graph_navigator.py

class NavigationEngine:
    def get_navigation_options(self, article_id: str, user_id: str) -> NavigationOptions:
        """
        Returns available navigation directions from current article.
        Options are ranked by recommendation score. (KG-14)
        """
        current = self.get_article_concepts(article_id)
        user_state = self.get_user_knowledge_state(user_id)

        return NavigationOptions(
            deeper=self._get_deeper(current, user_state),    # KG-03
            up=self._get_broader(current, user_state),        # KG-04
            next=self._get_next_recommended(user_state),      # KG-05
            related=self._get_related(current, user_state),   # KG-06
        )

    def _get_deeper(self, current, user_state):
        """Children in hierarchy + unread filter + score ranking"""
        children = self.graph.get_children(current.concept_id)
        return [c for c in children if c.id not in user_state.completed]

    def _get_broader(self, current, user_state):
        """Parents in hierarchy"""
        return self.graph.get_parents(current.concept_id)
```

### 12.4 Universal Traversal Guarantee (KG-08)

The system ensures all Shorts are eventually covered regardless of user navigation path:

1. **Visited set**: Track all completed/skipped Short IDs per user
2. **Unvisited queue**: All Shorts not in visited set, ordered by recommendation score
3. **Navigation stack** (KG-12): When user dives deeper, push current position; pop when deeper topic is exhausted
4. **Fallback**: If no deeper/related/up options exist, serve from unvisited queue
5. **Periodic sweep**: Background job checks for "orphaned" unread Shorts and injects them into the roadmap

### 12.5 Dynamic / Soft Edges (KG-17)

In addition to explicit edges created during Short generation:

- **k-NN edges**: Top-5 nearest neighbors by embedding cosine distance (auto-updated on new Short creation)
- **Co-citation edges**: Shorts citing the same source note get a "related" edge
- **Shared entity edges**: Shorts containing the same named entity (from NER) get linked

These dynamic edges supplement navigation and recommendation scoring.

### 12.6 Temporal Tracking (KG-16)

Each concept node tracks:
- `createdAt`: When concept first appeared
- `lastUpdatedAt`: When last Short updated this concept
- `supersededBy`: If a newer version of the concept exists
- Version history for concept evolution across sources

---

## 13. Adaptive Learning Engine

### 13.1 Architecture

The adaptive learning engine lives entirely on the Python backend, triggered on every user interaction (SYS-04).

```
┌─────────────────────────────────────────────────┐
│              ADAPTIVE LEARNING ENGINE            │
│                                                  │
│  ┌───────────────┐     ┌─────────────────────┐   │
│  │ User Modeler  │────►│ Roadmap Calculator  │   │
│  │ (BKT, AL-09)  │     │ (AL-01, AL-03)      │   │
│  └───────┬───────┘     └──────────┬──────────┘   │
│          │                        │              │
│  ┌───────▼───────┐     ┌──────────▼──────────┐   │
│  │ Context       │     │ Diversity Balancer  │   │
│  │ Analyzer      │     │ (AL-06, AL-11)      │   │
│  │ (AL-12)       │     └──────────┬──────────┘   │
│  └───────┬───────┘                │              │
│          │              ┌─────────▼──────────┐   │
│          └─────────────►│ Multi-Factor Scorer│   │
│                         │ (AL-02)            │   │
│                         └────────────────────┘   │
└─────────────────────────────────────────────────┘
```

### 13.2 Multi-Factor Scoring (AL-02)

Each unread Short is scored using weighted factors:

```python
score = (
    w_relevance * semantic_relevance(short, user.interests)    # 0.40
  + w_capability * capability_alignment(short, user.expertise) # 0.30
  + w_novelty * novelty_score(short, user.recent_interactions) # 0.30
)
```

Adjustable weights per user. Additional modifiers:
- **Temporal diversity** (AL-06): Penalty for same-topic consecutive recommendations
- **Difficulty alignment** (AL-07): Bonus for Shorts matching user's demonstrated level
- **Context** (AL-12): Time-of-day, session duration, device type

### 13.3 Bayesian Knowledge Tracing (AL-09)

Per-concept mastery model with four parameters:

```python
class BKTModel:
    p_know: float    # Prior probability of knowing concept
    p_learn: float   # Probability of learning on each attempt
    p_slip: float    # Probability of incorrect response despite knowing
    p_guess: float   # Probability of correct response despite not knowing

    def update(self, observed_correct: bool) -> float:
        """Returns updated P(know) after observing response"""
```

Updated after: quiz results (RA-03), interaction speed, skip patterns (SYS-06).

### 13.4 Cold Start (AL-08)

For new users after onboarding:
1. Content-based filtering from selected interests (ON-02)
2. Proficiency self-assessment (ON-05) seeds initial familiarity scores
3. First 20 Shorts served from highest-relevance content-based recs
4. After 20 interactions, collaborative signals begin contributing

### 13.5 Familiarity-Based Adaptation (AL-04, AL-05, SYS-06, SYS-18)

```
User quickly marks "done" → High familiarity inferred
  → Related beginner Shorts skipped or grouped into one summary (AL-04)

User frequently skips / slow interactions → Low familiarity inferred
  → Full detailed Shorts presented + additional foundational content (AL-05)

User provides "too easy"/"too hard" feedback (UI-10)
  → Direct difficulty preference update (SYS-18)
```

### 13.6 Exploration vs Exploitation (AL-11)

Contextual bandit algorithm (e.g., LinUCB):
- **Exploitation**: Recommend Shorts closely matching known interests (high relevance)
- **Exploration**: Occasionally introduce Shorts from new/adjacent topics (surprise factor)
- Balance ratio adapts based on user engagement feedback

---

## 14. RAG & Knowledge Query System

### 14.1 Query Pipeline (RQ-01–13)

```
User Question
     │
     ▼
┌────────────────┐
│ Query Expansion│  RQ-11: Add synonyms, related terms from KB
│ (lightweight)  │  Avoid full LLM rewrite to prevent semantic drift
└───────┬────────┘
        │
        ▼
┌────────────────┐
│ Hybrid Search  │  RQ-02: Dense (ChromaDB cosine) + Sparse (BM25 keyword)
│                │  User-scoped collection only (RQ-06)
│                │  Hierarchical: section → chunk granularity
└───────┬────────┘
        │ Top-k candidates (k=50)
        ▼
┌────────────────┐
│ Cross-Encoder  │  RQ-07: Re-score with joint query-chunk encoding
│ Reranking      │  e.g., BGE-Reranker or similar
└───────┬────────┘
        │ Top-20 reranked
        ▼
┌────────────────┐
│ MMR Diversify  │  RQ-08: λ ≈ 0.7 (balance relevance vs redundancy)
│                │  Ensures diverse coverage in context
└───────┬────────┘
        │ Top-10 diverse
        ▼
┌────────────────┐
│ Context        │  RQ-09: Multi-stage compression
│ Compression    │  1. Quality filter (drop low-confidence chunks)
│                │  2. Sentence-level redundancy pruning (cosine ≥ 0.92)
│                │  3. Relevance scoring + token budget management
└───────┬────────┘
        │ Compressed context
        ▼
┌────────────────┐
│ LLM Generate   │  Gemini: Grounded generation with citations (RQ-03)
│ + Citations    │  Each claim linked to source passage
└───────┬────────┘
        │
        ▼
   RagResponse { answer, citations[], followUpQuestions[] }
```

### 14.2 Task-Specific Retrieval Profiles (RQ-12)

| Task | MMR λ | Chunk Quota | Compression | Template |
|------|-------|-------------|-------------|----------|
| **Q&A** | 0.8 (precision) | 5 per source | Aggressive | Answer + cite |
| **Flashcard Gen** | 0.5 (coverage) | 3 per source | Moderate | Q/A pairs |
| **Summary** | 0.6 | 10 per source | Light | Narrative |
| **Audio Overview** | 0.6 | 8 per source | Moderate | Podcast script |
| **Mind Map** (RQ-13) | 0.4 (max diversity) | 2 per source | Heavy | Concept tree |

Profiles are configuration-driven, not hard-coded.

### 14.3 Mind Map Generation (RQ-13)

```
Input: Topic scope or Module
├── Retrieve relevant chunks across scope
├── Extract concepts via NER + clustering
├── Identify inter-concept relationships (prerequisite, related, part-of)
├── Build hierarchical tree structure
├── Render as interactive node-link diagram (graphview widget)
Output: NavigableGraphWidget on Flutter side
```

### 14.4 Audio Summary (RQ-10)

```
Input: Module or set of Shorts
├── LLM synthesis: Combine key points into cohesive narrative script
├── Text-to-speech: Generate audio file
├── Store in Cloud Storage
├── Stream to Flutter app for playback
Note: Distinct from per-Short TTS (SP-07) which is client-side flutter_tts
```

---

## 15. Spaced Repetition & Assessment

### 15.1 FSRS Integration (RA-01)

The **FSRS** (Free Spaced Repetition Scheduler) algorithm replaces SM-2:

```python
# Backend: assessment/fsrs_scheduler.py
from fsrs import FSRS, Card, Rating

scheduler = FSRS(desired_retention=0.9)

def schedule_review(card_state: FSRSCardState, rating: Rating) -> FSRSCardState:
    """
    rating: Rating.Again | Rating.Hard | Rating.Good | Rating.Easy
    Returns updated card with new due date, stability, difficulty
    """
    card = Card.from_state(card_state)
    updated = scheduler.review(card, rating)
    return updated.to_state()
```

- `desired_retention=0.9`: User has 90% recall probability at review time
- 21 trainable parameters, optimizable per-user after 1000+ reviews
- 20-30% fewer reviews than SM-2 for same retention

### 15.2 Quiz Generation Pipeline (RA-02, RA-08–12)

```
Short marked completed
     │
     ▼
┌────────────────────────┐
│ Concept Inventory      │  RA-09: Cluster chunk embeddings
│ Planning               │  Label concepts, score importance
└───────┬────────────────┘
        │
        ▼
┌────────────────────────┐
│ Per-Concept Retrieval  │  RA-10: Retrieve context per concept
│                        │  (not bulk retrieval)
└───────┬────────────────┘
        │
        ▼
┌────────────────────────┐
│ Question Generation    │  RA-08: Gemini generates:
│                        │  - Multiple choice
│                        │  - True/false
│                        │  - Fill-in-the-blank
│                        │  - Open-ended (AI-graded)
│                        │  - Short answer
│                        │  Difficulty adapted (RA-07)
└───────┬────────────────┘
        │
        ▼
┌────────────────────────┐
│ Output Dedup           │  RA-11: Deduplicate Q&A pairs
│                        │  that test same concept
└───────┬────────────────┘
        │
        ▼
┌────────────────────────┐
│ Conflict Handling      │  RA-12: Create comparison-style items
│                        │  for conflicting sources
└────────────────────────┘
```

### 15.3 Spaced Review Screen Flow

```
SpacedReviewScreen
  │
  ├── Fetch due cards (FSRS: dueDate <= now)
  ├── Display Short content as flashcard
  ├── User rates recall: Again | Hard | Good | Easy
  ├── FSRS reschedules card → new dueDate
  ├── Update user profile (familiarity, retention metrics)
  └── Show progress: X cards reviewed, Y remaining
```

---

## 16. Search & Discovery

### 16.1 Search Architecture (SD-01–06)

```
Flutter SearchScreen
  │ User types query
  ▼
Debounce (300ms)
  │
  ▼
API: GET /api/v1/search?q=...&filter=...&sort=...
  │
  ├── Keyword search: Firestore text fields (title, topics, tags)
  ├── Semantic search: ChromaDB vector similarity
  ├── Combine results (reciprocal rank fusion)
  ├── Apply filters (SD-02): topic, difficulty, read/unread, date, source, module
  ├── Apply sort (SD-03): relevance, recency, difficulty, popularity
  └── Return ranked results
```

### 16.2 Semantic Search (SD-04)

Uses the same ChromaDB collection as RAG but with simpler retrieval:
- Embed user query → ChromaDB similarity search → top-20 results
- No reranking, no compression (simpler than RAG)

### 16.3 Search Suggestions (SD-06)

As user types:
- Query prefix matching against topic names and Short titles
- Recent search history
- Trending topics based on aggregate engagement (SD-05)

---

## 17. Authentication & Onboarding

### 17.1 Authentication Flow (AP-01–07)

```
┌─────────────┐      ┌──────────────┐
│ Email/Pass  │      │ Google       │
│ Sign In     │      │ Sign In      │
│ (AP-01)     │      │ (AP-02)      │
└──────┬──────┘      └──────┬───────┘
       │                    │
       └────────┬───────────┘
                │
        ┌───────▼───────┐
        │ Firebase Auth  │
        │ Token          │
        └───────┬───────┘
                │
        ┌───────▼───────┐
        │ Create/Update  │
        │ User doc in    │
        │ Firestore      │
        └───────┬───────┘
                │
     ┌──────────┼──────────┐
     │                     │
┌────▼─────┐        ┌─────▼──────┐
│New User  │        │Existing    │
│→Onboarding│       │→Home Feed  │
└──────────┘        └────────────┘
```

**Guest Mode (AP-06)**: Anonymous Firebase Auth → limited features (read only, no sync). Guest data stored locally in Drift. On account creation (AP-07): migrate Drift data to Firestore.

**Session Persistence (AP-05)**: Firebase Auth persists session automatically. Auth token refreshed via Firebase SDK. Token injected into Dio requests via `AuthInterceptor`.

### 17.2 Onboarding Flow (ON-01–06)

```
FeatureShowcase (ON-01)
  │ Swipeable pages explaining:
  │ - Shorts concept
  │ - Knowledge Graph
  │ - Adaptive learning
  │ - Share intent
  ▼
InterestSelection (ON-02)
  │ Searchable topic chips (multi-select)
  │ Seeds: UserPreferences.interests
  ▼
SourceSetup (ON-03)
  │ URL input + predefined source catalog (CS-07)
  │ Optional — can skip
  ▼
GoalSelection (ON-04)
  │ Cards: "Learn AI", "Stay updated on tech", etc.
  │ Seeds: UserPreferences.goals
  ▼
ProficiencyAssessment (ON-05)
  │ Per-topic sliders: beginner / intermediate / advanced
  │ Seeds: UserPreferences.topicFamiliarity
  ▼
ON-06: Trigger initial content fetch + roadmap generation (SYS-14)
  │ Cold-start recommendations (AL-08)
  ▼
HomeScreen (Feed)
```

---

## 18. Offline & Sync Strategy

### 18.1 Offline-First Architecture (OS-01–06)

```
┌─────────────────────────────────────────────┐
│               FLUTTER APP                   │
│                                             │
│  ┌─────────────┐    ┌────────────────────┐  │
│  │ Riverpod    │    │ Drift (SQLite)     │  │
│  │ Providers   │◄───│ Local Cache        │  │
│  │             │    │                    │  │
│  │ Read: Local │    │ cached_shorts      │  │
│  │ first, then │    │ cached_modules     │  │
│  │ Firestore   │    │ pending_interactions│ │
│  └──────┬──────┘    │ user_preferences   │  │
│         │           └─────────┬──────────┘  │
│         │                     │              │
│    Online?──────┐        Sync Queue         │
│         │   No  │             │              │
│         │   │   │     ┌───────▼──────────┐   │
│    ┌────▼───▼───┐     │ On reconnect:    │   │
│    │ Show local │     │ Flush queue to   │   │
│    │ cached data│     │ Firestore (OS-04)│   │
│    └────────────┘     └──────────────────┘   │
└─────────────────────────────────────────────┘
```

### 18.2 Data Flow: Read Path

1. **Provider first checks Drift** (local SQLite) for cached data
2. If cache hit and fresh (< cache TTL): return immediately
3. If online: fetch from Firestore in background, update Drift cache
4. If offline: serve stale cache with "offline" indicator (OS-03)

### 18.3 Data Flow: Write Path

1. **Write to Drift immediately** (PendingInteractions table)
2. If online: also write to Firestore simultaneously
3. If offline: queue in Drift with `synced = false`
4. **On reconnect** (OS-04): SyncRepository flushes pending items to Firestore
5. Mark `synced = true` after successful Firestore write

### 18.4 Conflict Resolution (OS-06)

- **Last-write-wins** for user preferences and settings
- **Merge** for interactions (all interactions from all devices are valid)
- **Server-authoritative** for Shorts content and KG data
- Firestore's built-in offline persistence (OS-02) handles document-level conflicts

### 18.5 Firestore Persistence Config

```dart
// bootstrap.dart
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,          // OS-02
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // OS-02: unlimited cache
);
```

### 18.6 Connectivity Monitoring (OS-03)

```dart
// ConnectivityBanner widget — shown at top of screen when offline
@riverpod
Stream<bool> connectivity(Ref ref) =>
  Connectivity().onConnectivityChanged.map(
    (result) => result.first != ConnectivityResult.none,
  );
```

---

## 19. Notifications

### 19.1 Push Notification Architecture (NO-01–05)

```
┌───────────────────┐          ┌──────────┐
│ Cloud Function    │          │   FCM    │
│ (Trigger Events)  │─────────►│ (Push)   │
│                   │          └────┬─────┘
│ - New Short from  │               │
│   monitored source│          ┌────▼─────┐
│ - Spaced rep due  │          │ Flutter  │
│ - Streak at risk  │          │ App      │
│ - Achievement     │          │          │
└───────────────────┘          │ firebase │
                               │_messaging│
                               │ handler  │
                               └──────────┘
```

### 19.2 Notification Types

| Type | Trigger | Deep Link (NO-04) | Req |
|------|---------|-----------|-----|
| New Short | Source polling finds new content | `/home/feed/:id` | NO-01 |
| Review reminder | FSRS card due date reached | `/review` | NO-01, RA-01 |
| Streak reminder | 8 PM if no activity today | `/home/feed` | NO-05 |
| Source update | RSS/URL has new content | `/sources/:id` | NO-01 |
| Achievement | Badge earned | `/analytics/achievements` | AT-08 |

### 19.3 Notification Preferences (NO-02)

Stored in `UserSettings.notificationTopics`:
- Per-topic enable/disable
- Frequency: immediate / daily digest / weekly digest
- Quiet hours: configurable time range (no notifications)

### 19.4 In-App Notifications (NO-03)

- Real-time Firestore listener on `users/{uid}/notifications` sub-collection
- Shown as a badge count on notification icon
- Subtle snackbar for real-time content updates

---

## 20. Analytics & Gamification

### 20.1 Analytics Dashboard (AT-05)

```
┌──────────────────────────────────────────┐
│           Analytics Dashboard            │
│                                          │
│  ┌─────────────┐  ┌─────────────────┐   │
│  │ Streak: 15  │  │ Shorts: 142     │   │
│  │ Best: 30    │  │ Topics: 12      │   │
│  │ (AT-01)     │  │ Time: 24h       │   │
│  │             │  │ (AT-02)         │   │
│  └─────────────┘  └─────────────────┘   │
│                                          │
│  ┌──────────────────────────────────┐   │
│  │ Topic Progress (Radar Chart)     │   │
│  │ (AT-03, fl_chart)                │   │
│  │                                   │   │
│  │    AI ──── ML                    │   │
│  │   /    \  /  \                   │   │
│  │ NLP ── Data ── Math              │   │
│  └──────────────────────────────────┘   │
│                                          │
│  ┌──────────────────────────────────┐   │
│  │ Engagement Over Time (Line Chart)│   │
│  │ (AT-05)                          │   │
│  └──────────────────────────────────┘   │
│                                          │
│  ┌──────────────────────────────────┐   │
│  │ Learning Velocity (AT-07)        │   │
│  │ 4.2 shorts/day (↑12% this week) │   │
│  └──────────────────────────────────┘   │
│                                          │
│  ┌──────────────────────────────────┐   │
│  │ Reading History (AT-04)          │   │
│  │ - "Neural Networks" 2h ago       │   │
│  │ - "Backpropagation" yesterday    │   │
│  └──────────────────────────────────┘   │
└──────────────────────────────────────────┘
```

### 20.2 Gamification (AT-08)

| Badge | Condition | Icon |
|-------|-----------|------|
| First Steps | Complete first Short | Star |
| Curious Mind | Read 10 Shorts | Lightbulb |
| Deep Diver | Dive 3 levels deep | Anchor |
| Streak Master | 7-day streak | Fire |
| Knowledge Seeker | 50 Shorts completed | Brain |
| Explorer | Cover 5 topics | Compass |
| Quiz Ace | Score 100% on quiz | Trophy |
| Source Hunter | Add 5 sources | Magnifier |

### 20.3 KG Progress Visualization (AT-06)

The KnowledgeGraphScreen overlays user progress on the graph:
- **Green nodes**: Mastered (completed + high retention)
- **Yellow nodes**: In progress (started but not completed)
- **Gray nodes**: Unread
- **Red outline**: Low retention (due for review)

---

## 21. Browser Extension Architecture

### 21.1 Overview (BE-01–09)

The browser extension is a **separate project** (TypeScript + React) that communicates with the same Firebase backend.

```
geeky-extension/                    # Separate repo
├── src/
│   ├── background/                 # Service worker (Manifest V3)
│   │   └── service-worker.ts
│   ├── content/                    # Content script (page injection)
│   │   ├── highlighter.ts          # BE-03: Highlight system
│   │   └── auto-highlighter.ts     # BE-08: AI-powered
│   ├── popup/                      # Extension popup (React)
│   │   ├── QuickSave.tsx           # BE-04
│   │   └── HighlightDashboard.tsx  # BE-03
│   ├── options/                    # Settings page
│   │   └── TemplateEditor.tsx      # BE-07
│   └── shared/
│       ├── firebase.ts             # Firebase Auth + Firestore
│       ├── metadata-extractor.ts   # BE-07: Schema.org, OpenGraph
│       └── storage.ts              # Local storage for offline (BE-06)
├── manifest.json                   # Manifest V3 (BE-01)
├── vite.config.ts                  # Build for Chrome, Firefox, Safari, Edge
└── package.json
```

### 21.2 Extension → App Communication

```
Extension captures content (BE-02)
  → Writes Note to Firestore `notes` collection (BE-05)
  → Cloud Function triggers processing pipeline (SYS-01)
  → Short generated → visible in Flutter app
```

Highlights (BE-03) are stored in a Firestore sub-collection and synced across devices.

---

## 22. API Design

### 22.1 Backend API Endpoints

Base URL: `https://geeky-backend-XXXX.run.app/api/v1`

#### Notes & Ingestion

| Method | Endpoint | Description | Req |
|--------|----------|-------------|-----|
| POST | `/notes` | Create note (triggers pipeline) | MI-10, SYS-01 |
| PUT | `/notes/{id}` | Update note (triggers re-processing) | LM-01, SYS-08 |
| DELETE | `/notes/{id}` | Delete note (cascade) | LM-02, SYS-09 |
| GET | `/notes` | List user's notes | MI-10 |
| GET | `/notes/{id}` | Get note detail + source summary | MI-13 |
| POST | `/notes/url` | Ingest from URL | MI-04 |

#### Shorts (Articles)

| Method | Endpoint | Description | Req |
|--------|----------|-------------|-----|
| GET | `/articles` | List Shorts (paginated, filtered) | SM-01 |
| GET | `/articles/{id}` | Get Short detail | SM-01 |
| GET | `/articles/{id}/navigation` | Get navigation options | KG-11 |

#### Recommendations

| Method | Endpoint | Description | Req |
|--------|----------|-------------|-----|
| GET | `/recommendations` | Get current roadmap | AL-01 |
| POST | `/recommendations/recalculate` | Force recalculation | SYS-04 |

#### Knowledge Graph

| Method | Endpoint | Description | Req |
|--------|----------|-------------|-----|
| GET | `/kg/graph` | Full graph data for visualization | KG-13 |
| GET | `/kg/nodes/{id}/neighbors` | Get neighbors by direction | KG-03–06 |
| GET | `/kg/concepts` | List all concepts | KG-01 |

#### RAG / Query

| Method | Endpoint | Description | Req |
|--------|----------|-------------|-----|
| POST | `/rag/query` | Ask a question | RQ-01 |
| POST | `/rag/follow-up` | Follow-up in session | RQ-05 |
| POST | `/rag/mindmap` | Generate mind map | RQ-13 |
| POST | `/rag/audio-summary` | Generate audio overview | RQ-10 |

#### Search

| Method | Endpoint | Description | Req |
|--------|----------|-------------|-----|
| GET | `/search?q=&filter=&sort=` | Hybrid search | SD-01–06 |
| GET | `/search/suggestions?q=` | Type-ahead suggestions | SD-06 |

#### Quiz / Assessment

| Method | Endpoint | Description | Req |
|--------|----------|-------------|-----|
| POST | `/quiz/generate` | Generate quiz for Short/Module | RA-02 |
| POST | `/quiz/grade` | Grade quiz answers | RA-03 |
| GET | `/quiz/due-cards` | Get FSRS due cards | RA-01 |
| POST | `/quiz/review` | Submit FSRS review rating | RA-01 |

#### Modules

| Method | Endpoint | Description | Req |
|--------|----------|-------------|-----|
| GET | `/modules` | List modules | MO-01 |
| POST | `/modules` | Create module | MO-03 |
| PUT | `/modules/{id}` | Update module | MO-05 |
| DELETE | `/modules/{id}` | Delete module | MO-06 |

#### Sources

| Method | Endpoint | Description | Req |
|--------|----------|-------------|-----|
| GET | `/sources` | List sources | CS-01 |
| POST | `/sources` | Add source | CS-01 |
| PUT | `/sources/{id}` | Update source | CS-01 |
| DELETE | `/sources/{id}` | Delete source | CS-01 |
| POST | `/sources/validate` | Validate URL/RSS | CS-05 |
| GET | `/sources/catalog` | Predefined sources | CS-07 |

#### User / Analytics

| Method | Endpoint | Description | Req |
|--------|----------|-------------|-----|
| GET | `/users/profile` | Get user profile | AP-03 |
| PUT | `/users/profile` | Update profile | AP-04 |
| POST | `/users/interactions` | Record interaction | UI-01–12 |
| GET | `/analytics/dashboard` | Analytics data | AT-01–08 |
| POST | `/users/export` | Export user data (JSON/CSV) | SP-08, PR-02 |
| DELETE | `/users/account` | Delete account + all data | SP-10, PR-02 |

### 22.2 Authentication (All Endpoints)

All endpoints require Firebase ID token in the `Authorization` header:

```
Authorization: Bearer <firebase_id_token>
```

Backend middleware verifies token via Firebase Admin SDK and extracts `user_id`.

### 22.3 Error Response Format

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Article with id 'abc123' not found",
    "details": null
  }
}
```

Standard HTTP status codes: 200, 201, 400, 401, 403, 404, 429, 500.

---

## 23. Error Handling

### 23.1 Flutter Error Strategy

**Failure Hierarchy** (sealed class pattern):

```dart
sealed class Failure {
  final String message;
  final String? code;
  const Failure(this.message, {this.code});
}

class NetworkFailure extends Failure { /* No internet */ }
class ServerFailure extends Failure { /* 5xx errors */ }
class AuthFailure extends Failure { /* 401/403 */ }
class NotFoundFailure extends Failure { /* 404 */ }
class RateLimitFailure extends Failure { /* 429 */ }
class CacheFailure extends Failure { /* Local DB error */ }
class ValidationFailure extends Failure { /* Invalid input */ }
```

**Repository Pattern**: Repositories catch exceptions from data sources and return domain-specific failures. Providers handle `AsyncValue.error` states.

**Global Error Handler**:

```dart
// bootstrap.dart
FlutterError.onError = (details) {
  // Log to Firebase Crashlytics
  FirebaseCrashlytics.instance.recordFlutterFatalError(details);
};
PlatformDispatcher.instance.onError = (error, stack) {
  FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  return true;
};
```

### 23.2 Backend Error Strategy

**Graceful Degradation (RE-02)**:

| Service Down | Fallback |
|-------------|----------|
| ChromaDB unreachable | Fall back to keyword-only search in Firestore |
| Gemini rate-limited | Queue with exponential backoff, serve cached responses |
| Speech-to-Text unavailable | Skip audio processing, log warning, mark task partial |
| Network timeout | Retry 3x with exponential backoff (RE-03) |

**Processing Task Tracking (LM-08)**:

Every pipeline operation creates a `ProcessingTask` document:
- Status lifecycle: `pending → processing → completed | failed`
- Failed tasks include `errorMessage` for debugging
- Flutter app shows processing status badge on note cards

### 23.3 Retry Policy

```python
# Backend: Exponential backoff with jitter
MAX_RETRIES = 3
BASE_DELAY = 1.0  # seconds

for attempt in range(MAX_RETRIES):
    try:
        result = await operation()
        break
    except TransientError:
        delay = BASE_DELAY * (2 ** attempt) + random.uniform(0, 1)
        await asyncio.sleep(delay)
```

---

## 24. Security Architecture

### 24.1 Security Layers

```
┌──────────────────────────────────────────┐
│ Layer 1: Transport (SE-01)               │
│ HTTPS/TLS on all API communication       │
├──────────────────────────────────────────┤
│ Layer 2: Authentication (SE-02)          │
│ Firebase Auth (email/pass + Google)      │
│ ID token verification on every request   │
├──────────────────────────────────────────┤
│ Layer 3: Authorization (SE-03)           │
│ Firestore rules: userId == auth.uid      │
│ ChromaDB: user-scoped collections        │
│ API: user_id extracted from token        │
├──────────────────────────────────────────┤
│ Layer 4: Input Validation (SE-06)        │
│ Pydantic models validate all inputs      │
│ Bleach sanitizes HTML in user content    │
│ URL validation before fetching           │
├──────────────────────────────────────────┤
│ Layer 5: Rate Limiting (SE-05)           │
│ Per-user: 1000 API calls/day             │
│ Token bucket algorithm                   │
├──────────────────────────────────────────┤
│ Layer 6: Secrets (SE-04)                 │
│ API keys in Secret Manager / env vars    │
│ Never exposed in client responses        │
├──────────────────────────────────────────┤
│ Layer 7: CORS (SE-07)                    │
│ Whitelist allowed origins in production  │
└──────────────────────────────────────────┘
```

### 24.2 Data Isolation (PR-01)

- **Firestore**: Security rules enforce `userId == auth.uid` on every document
- **ChromaDB**: Separate collection per user (`user_{uid}_chunks`)
- **Cloud Storage**: Folder per user with Firebase Storage security rules
- **API**: All queries filtered by `user_id` from auth token

### 24.3 Privacy & GDPR (PR-01–06)

| Requirement | Implementation |
|------------|----------------|
| PR-01 Data isolation | See above |
| PR-02 GDPR portability | `/users/export` endpoint → JSON/CSV download |
| PR-02 Right to erasure | `/users/account` DELETE → cascades through all collections + ChromaDB |
| PR-03 Data retention | Configurable in app_config, enforced by scheduled Cloud Function |
| PR-04 Anonymized analytics | Aggregate metrics only, no PII in analytics collection |
| PR-05 Export formats | JSON and CSV |
| PR-06 Transparent AI | Recommendation includes `reason` and `explanation` fields |

---

## 25. Testing Strategy

### 25.1 Flutter Testing

| Level | Tools | Coverage Target |
|-------|-------|----------------|
| **Unit** | flutter_test, mocktail | Domain layer: 90%+ |
| **Widget** | flutter_test, golden_toolkit | Critical widgets: 80%+ |
| **Integration** | integration_test | Core flows: login, feed, search |

**Key Testing Patterns**:

```dart
// Unit test: Repository with mocked data sources
test('shortsRepository returns cached data when offline', () async {
  when(() => networkInfo.isConnected).thenReturn(false);
  when(() => localSource.getCachedShorts()).thenReturn(mockShorts);

  final result = await repository.getShorts();

  expect(result, equals(mockShorts));
  verifyNever(() => remoteSource.getShorts(any()));
});

// Widget test with Riverpod overrides
testWidgets('ShortsFeedScreen shows shorts', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shortsFeedProvider.overrideWith((ref) => Stream.value(mockShorts)),
      ],
      child: const MaterialApp(home: ShortsFeedScreen()),
    ),
  );
  expect(find.text('Neural Networks'), findsOneWidget);
});
```

### 25.2 Backend Testing

| Level | Tools | Coverage Target |
|-------|-------|----------------|
| **Unit** | pytest, pytest-asyncio | Services: 85%+ |
| **Integration** | pytest, httpx | API routes: 80%+ |
| **Pipeline** | pytest with fixtures | Full pipeline: critical paths |

```python
# Backend unit test example
@pytest.mark.asyncio
async def test_dedup_exact_match():
    dedup = ExactDeduplicator()
    chunk1 = Chunk(text="Hello world")
    chunk2 = Chunk(text="Hello world")

    result = await dedup.check(chunk1, existing=[chunk2])
    assert result.is_duplicate is True
    assert result.stage == "exact"
```

---

## 26. Deployment & Infrastructure

### 26.1 Deployment Architecture

```
┌──────────────────────────────────────────────────┐
│                 GOOGLE CLOUD                      │
│                                                  │
│  ┌──────────────┐   ┌─────────────────────────┐  │
│  │ Cloud Run    │   │ Cloud Run               │  │
│  │ (FastAPI)    │   │ (ChromaDB)              │  │
│  │              │   │                         │  │
│  │ Scale to 0   │   │ Persistent Volume:      │  │
│  │ Auto-scaling │   │ Cloud Storage bucket    │  │
│  └──────┬───────┘   └─────────────────────────┘  │
│         │                                        │
│  ┌──────▼───────┐   ┌─────────────────────────┐  │
│  │ Cloud        │   │ Secret Manager          │  │
│  │ Functions    │   │ (API keys, configs)     │  │
│  │ (Triggers)   │   └─────────────────────────┘  │
│  └──────────────┘                                │
│                                                  │
│  ┌──────────────────────────────────────────────┐│
│  │                FIREBASE                       ││
│  │  Auth  │  Firestore  │  Storage  │  FCM      ││
│  └──────────────────────────────────────────────┘│
└──────────────────────────────────────────────────┘
```

### 26.2 Cloud Run Configuration

**FastAPI Backend**:
```yaml
# cloudbuild.yaml
steps:
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/geeky-backend', '.']
  - name: 'gcr.io/cloud-builders/gcloud'
    args: ['run', 'deploy', 'geeky-backend',
           '--image', 'gcr.io/$PROJECT_ID/geeky-backend',
           '--platform', 'managed',
           '--region', 'us-central1',
           '--allow-unauthenticated',
           '--memory', '512Mi',
           '--cpu', '1',
           '--min-instances', '0',    # Scale to zero (CO-02)
           '--max-instances', '3',
           '--timeout', '300']        # 5 min for pipeline ops
```

**ChromaDB**:
```yaml
# Separate Cloud Run service
gcloud run deploy chroma-service \
  --image chromadb/chroma:latest \
  --memory 1Gi \
  --min-instances 0 \
  --max-instances 1 \
  --port 8000
```

### 26.3 Flutter Build & Release

```bash
# Android release build
flutter build appbundle --release

# iOS release build
flutter build ipa --release
```

### 26.4 CI/CD Pipeline

```
Push to main
  │
  ├── Flutter CI (GitHub Actions)
  │   ├── flutter analyze
  │   ├── flutter test
  │   ├── flutter build appbundle
  │   └── (optional) firebase app distribution
  │
  └── Backend CI (GitHub Actions)
      ├── pytest
      ├── docker build
      └── gcloud run deploy
```

---

## 27. Performance Optimization

### 27.1 Flutter Performance (PF-06–08)

| Technique | Req | Implementation |
|-----------|-----|----------------|
| **60fps scrolling** | PF-06 | `ListView.builder` with `const` widgets, avoid rebuilds |
| **Lazy loading** | PF-07 | Paginated Firestore queries, infinite scroll |
| **Image caching** | PF-08 | `CachedNetworkImage` with disk + memory cache |
| **Smooth animations** | PF-06 | `flutter_animate` for declarative transitions |
| **Skeleton loading** | PF-06 | `shimmer` package for loading placeholders |
| **Widget caching** | PF-06 | `AutomaticKeepAliveClientMixin` for tab views |
| **Build optimization** | PF-06 | `const` constructors, `RepaintBoundary` for complex widgets |

### 27.2 Backend Performance (PF-01–05, PF-09)

| Target | Req | Technique |
|--------|-----|-----------|
| **API < 500ms** | PF-01 | Firestore composite indexes, response caching |
| **Processing < 10s** | PF-03 | Async pipeline, parallel extraction + embedding |
| **Vector search < 200ms** | PF-04 | ChromaDB HNSW index, 768-dim embeddings |
| **Search < 200ms** | PF-05 | Compound Firestore queries + cached embeddings |
| **Rec calc < 2s** | PF-09 | Pre-computed scores, incremental updates |

### 27.3 Cost Optimization (CO-01–05)

| Strategy | Req | Implementation |
|----------|-----|----------------|
| **Scale to zero** | CO-02 | Cloud Run `min-instances: 0` |
| **Batch processing** | CO-03 | Queue notes, process in batch every 5 min |
| **Query indexing** | CO-04 | Composite Firestore indexes for common queries |
| **Embedding cache** | CO-05 | Cache frequently queried embeddings in memory |
| **Free tier limits** | CO-01 | Monitor usage against free tier quotas |

---

## 28. Requirement Traceability

### 28.1 Full Requirement → Architecture Mapping

Every requirement from REQUIREMENTS.md is traced to its architectural component:

| Req ID Range | Domain | Architecture Layer |
|-------------|--------|-------------------|
| MI-01–13 | Media Ingestion | Flutter: notes feature + share intent; Backend: pipeline/extractors |
| CP-01–24 | Content Processing | Backend: pipeline/* (orchestrator, chunker, dedup, embedder, summarizer) |
| SM-01–10 | Shorts Management | Flutter: shorts feature; Firestore: articles; Backend: lifecycle |
| MO-01–09 | Modules | Flutter: modules feature; Backend: lifecycle/module_lifecycle |
| KG-01–17 | Knowledge Graph | Backend: knowledge_graph/*; Flutter: knowledge_graph feature |
| AL-01–13 | Adaptive Learning | Backend: recommendation/*; Triggered by SYS-04 |
| UP-01–10 | User Profiling | Firestore: users collection; Backend: recommendation/user_modeler |
| RA-01–12 | Retention & Assessment | Backend: assessment/*; Flutter: quiz feature; FSRS |
| RQ-01–13 | RAG / Knowledge Query | Backend: rag/*; Flutter: rag_query feature |
| SD-01–06 | Search & Discovery | Backend: hybrid search; Flutter: search feature |
| UI-01–12 | User Interactions | Flutter: shorts/presentation (actions, gestures, tracking) |
| SS-01–04 | Social & Sharing | Flutter: share_plus, receive_sharing_intent, deep links |
| NO-01–05 | Notifications | Firebase FCM; Cloud Functions triggers; Flutter: notifications feature |
| SP-01–11 | Settings | Flutter: settings feature; Drift + SharedPreferences |
| AP-01–07 | Authentication | Firebase Auth; Flutter: auth feature; GoRouter guards |
| ON-01–06 | Onboarding | Flutter: onboarding feature (5 screens); Seeds user profile |
| OS-01–06 | Offline & Sync | Drift local DB; Firestore persistence; SyncRepository |
| AT-01–08 | Analytics | Flutter: analytics feature (fl_chart); Firestore: analytics |
| CS-01–07 | Content Sources | Flutter: sources feature; Backend: sources/* |
| LM-01–08 | Lifecycle Management | Backend: lifecycle/*; Cloud Functions triggers |
| BE-01–09 | Browser Extension | Separate TypeScript/React project; Shared Firebase backend |
| PF-01–09 | Performance | Across all layers (see Section 27) |
| SC-01–06 | Scalability | Cloud Run auto-scaling; Firestore limits; ChromaDB separation |
| RE-01–06 | Reliability | Offline-first; Graceful degradation; Retry policies |
| SE-01–07 | Security | Firebase Auth; Firestore rules; Input validation; Rate limiting |
| PR-01–06 | Privacy | Data isolation; GDPR endpoints; Anonymized analytics |
| CO-01–05 | Cost | Free tier optimization; Scale-to-zero; Batch processing |
| MA-01–07 | Maintainability | Feature-first structure; Modular backend; Structured logging |
| AC-01–06 | Accessibility | Semantic labels; High contrast; TTS; Responsive layout |
| QM-01–06 | Quality Metrics | Backend evaluation pipeline; Logged metrics |
| SYS-01–22 | Automated Behaviors | Cloud Functions triggers → Backend services |

### 28.2 User Story Coverage

All 55 user stories (US-01–US-55) are covered by the features and screens listed in Section 9. Each user story maps to one or more screens in Section 10.

---

## Appendix: pubspec.yaml Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_riverpod: ^3.0.0
  riverpod_annotation: ^3.0.0

  # Navigation
  go_router: ^14.0.0

  # Firebase
  firebase_core: ^3.0.0
  firebase_auth: ^5.0.0
  cloud_firestore: ^5.0.0
  firebase_storage: ^12.0.0
  firebase_messaging: ^15.0.0

  # Networking
  dio: ^5.4.0
  retrofit: ^4.1.0

  # Models
  freezed_annotation: ^2.4.0
  json_annotation: ^4.9.0

  # Local Database
  drift: ^2.22.0
  sqlite3_flutter_libs: ^0.5.0

  # UI
  markdown_widget: ^2.3.0
  fl_chart: ^0.69.0
  graphview: ^1.2.0
  flutter_animate: ^4.5.0
  shimmer: ^3.0.0
  cached_network_image: ^3.3.0
  flex_color_scheme: ^8.0.0

  # Features
  receive_sharing_intent: ^1.8.0
  share_plus: ^9.0.0
  flutter_tts: ^4.0.0
  connectivity_plus: ^6.0.0
  file_picker: ^8.0.0
  image_picker: ^1.0.0
  url_launcher: ^6.2.0
  flutter_local_notifications: ^17.0.0
  flutter_secure_storage: ^9.0.0
  shared_preferences: ^2.2.0
  uuid: ^4.3.0

  # Payments
  purchases_flutter: ^7.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

  # Code Generation
  build_runner: ^2.4.0
  riverpod_generator: ^3.0.0
  freezed: ^2.5.0
  json_serializable: ^6.8.0
  retrofit_generator: ^8.1.0
  drift_dev: ^2.22.0

  # Testing
  mocktail: ^1.0.0
  golden_toolkit: ^0.15.0
```

---

# Architecture Patterns: Detailed Design for Geeky

This document provides concrete architectural patterns and implementation strategies for the Geeky platform, synthesized from production systems and research.

---

## 1. SHORT-FORM CONTENT INGESTION PIPELINE

### 1.1 Complete Flow Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      SHORT-FORM CONTENT INGESTION PIPELINE                  │
└─────────────────────────────────────────────────────────────────────────────┘

REAL-TIME LAYER (Milliseconds)
┌──────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  1. Content Received                                                         │
│     ↓                                                                        │
│  2. Basic Validation (metadata, format)                                      │
│     ↓                                                                        │
│  3. Chunking (fixed-size: 512 tokens)                                        │
│     ↓                                                                        │
│  4. Quick Entity Extraction (LLM prompt with context)                        │
│     • Prompt includes: "Known entities: [sample from existing KG]"           │
│     • Temperature: 0 (deterministic)                                        │
│     • Max tokens: 200                                                        │
│     ↓                                                                        │
│  5. Embed Chunk & Entities                                                   │
│     • Model: gemini-embedding-001 (768 dims)                                │
│     • Store: Chroma collection (user-scoped)                                │
│     ↓                                                                        │
│  6. Preview KG (Show user: "Found 15 new concepts")                          │
│     ↓                                                                        │
│  7. User Confirmation (Accept scope or refine)                              │
│     ↓                                                                        │
│  8. Write to Event Stream                                                    │
│     • Kafka topic: "shorts.raw.extracted"                                    │
│     • Payload: Raw entities, chunks, embeddings                             │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘

BATCH LAYER (Hourly/Nightly)
┌──────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  9. Consume Event Stream                                                     │
│     ↓                                                                        │
│  10. Batch NER + Entity Linking                                              │
│      • Model: Fine-tuned BERT-biaffine                                       │
│      • Confidence threshold: 0.85                                            │
│      ↓                                                                       │
│  11. Deduplication & Entity Resolution                                       │
│      • Composite score: 0.3*string + 0.5*semantic + 0.2*topology           │
│      • Strategy:                                                            │
│        - score > 0.95: Auto-merge                                           │
│        - 0.80-0.95: Human review queue                                      │
│        - < 0.80: Create link/alias                                          │
│      ↓                                                                       │
│  12. Validate Relationships                                                  │
│      • Check: Does relationship exist in KG?                                │
│      • Merge: Combine with existing edges                                   │
│      ↓                                                                       │
│  13. Update KG (with provenance)                                             │
│      • Add nodes: With source short ID + timestamp                          │
│      • Add/merge edges: Track confidence, origin                            │
│      ↓                                                                       │
│  14. Compute Affected Learning Paths                                         │
│      • Analyze: Which users' paths are affected?                            │
│      • Invalidate caches: Mark for recomputation                            │
│      ↓                                                                       │
│  15. Notify Users of Path Updates                                            │
│      • Real-time: WebSocket to active users                                 │
│      • Async: Email digest to inactive users                                │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘

SERVING LAYER (Always-on)
┌──────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  16. KG Query Service                                                        │
│      • Endpoint: GET /api/kg/entities/{id}                                   │
│      • Latency: <50ms (cached)                                               │
│                                                                              │
│  17. Learning Path Service                                                   │
│      • Endpoint: GET /api/paths/user/{id}/recommendations                    │
│      • Algorithm: BFS with 2-hop depth limit                                │
│      • Cache hit rate target: 70%                                            │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Real-Time Entity Extraction Prompt

```
System Prompt:
"""
You are an educational knowledge graph curator. Extract educational concepts,
skills, and prerequisites from the following short-form content.

EXISTING CONCEPTS (to avoid duplication):
{known_concepts_sample}

RULES:
1. Only extract concepts present in the content
2. Avoid duplicating existing concepts (match by meaning, not exact string)
3. For each concept, provide:
   - name: Clean, canonical name (e.g., "Neural Networks" not "deep learning")
   - type: TOPIC | SKILL | CONCEPT | PREREQUISITE
   - confidence: 0.0-1.0 (how certain are you this was in the content?)
4. For relationships, specify:
   - source: Concept A
   - target: Concept B
   - relationship: PREREQUISITE_FOR | RELATED_TO | SUBTOPIC_OF

Output as JSON list.
"""

Content: {short_transcript}

Response Format:
{
  "entities": [
    {"name": "...", "type": "...", "confidence": 0.95},
    ...
  ],
  "relationships": [
    {"source": "...", "target": "...", "relationship": "..."},
    ...
  ]
}
```

### 1.3 Chunking Strategy Decision

**For Geeky shorts (typically 5-15 minutes):**

```python
def chunk_short_content(transcript: str, max_chunk_size: int = 512) -> List[str]:
    """
    Strategy: Fixed-size chunking with semantic awareness

    For short-form content, fixed-size works well because:
    1. Shorts are typically coherent, single-topic
    2. 5-10 minute duration = ~1500-3000 tokens
    3. Fits neatly into 2-4 chunks of 512 tokens
    4. No need for complex semantic clustering
    """
    tokens = tokenize(transcript)

    chunks = []
    for i in range(0, len(tokens), max_chunk_size):
        chunk_tokens = tokens[i:i+max_chunk_size]

        # Try to end at sentence boundary
        while chunk_tokens and not ends_at_sentence(chunk_tokens[-1]):
            chunk_tokens = chunk_tokens[:-1]

        if chunk_tokens:  # Only add non-empty chunks
            chunks.append(detokenize(chunk_tokens))

    return chunks
```

---

## 2. ENTITY DEDUPLICATION & KNOWLEDGE GRAPH UPDATES

### 2.1 Deduplication Algorithm (Production Implementation)

```python
from dataclasses import dataclass
from typing import List, Tuple
import numpy as np
from scipy.spatial.distance import cosine
from difflib import SequenceMatcher

@dataclass
class EntityDuplicateCandidate:
    entity_a_id: str
    entity_b_id: str
    string_similarity: float
    semantic_similarity: float
    topology_similarity: float
    composite_score: float
    recommendation: str  # "auto_merge", "review", "create_link"

class KGDeduplicator:
    def __init__(self, embedding_model, kg_graph):
        self.embedding_model = embedding_model
        self.kg = kg_graph

        # Configuration
        self.string_weight = 0.3
        self.semantic_weight = 0.5
        self.topology_weight = 0.2

        self.auto_merge_threshold = 0.95
        self.review_threshold = 0.80

    def find_duplicates(self, new_entity: Entity) -> List[EntityDuplicateCandidate]:
        """
        Find candidate duplicates for a new entity.

        Strategy: Candidate generation → Similarity scoring → Decision
        """
        # Step 1: Candidate generation (fast)
        candidates = self._generate_candidates(new_entity)

        # Step 2: Compute similarity scores
        scored = [
            self._score_candidate(new_entity, candidate)
            for candidate in candidates
        ]

        # Step 3: Filter by composite score
        filtered = [
            s for s in scored
            if s.composite_score >= self.review_threshold
        ]

        return sorted(filtered, key=lambda x: -x.composite_score)

    def _generate_candidates(self, entity: Entity) -> List[Entity]:
        """
        Generate candidate duplicates using fast heuristics.

        Strategies:
        1. Name similarity: Fuzzy match on entity names
        2. Type matching: Same entity type
        3. Neighbor overlap: Check KG neighbors
        """
        candidates = []

        # Strategy 1: Fuzzy name matching
        for existing in self.kg.all_entities():
            if existing.type != entity.type:
                continue

            # Quick string similarity threshold
            str_sim = self._string_similarity(entity.name, existing.name)
            if str_sim > 0.6:  # Candidate threshold (lower than final)
                candidates.append(existing)

        # Strategy 2: Neighbor overlap (for type-mismatch catch)
        if entity.description:
            similar_by_embed = self._find_similar_embeddings(
                entity.description,
                top_k=5
            )
            candidates.extend(similar_by_embed)

        return list(set(candidates))  # Remove duplicates

    def _score_candidate(
        self,
        new_entity: Entity,
        candidate: Entity
    ) -> EntityDuplicateCandidate:
        """
        Compute composite similarity score using three signals.
        """
        # Signal 1: String similarity (lexical)
        string_sim = self._string_similarity(new_entity.name, candidate.name)

        # Signal 2: Semantic similarity (embedding)
        semantic_sim = self._semantic_similarity(
            new_entity.description or new_entity.name,
            candidate.description or candidate.name
        )

        # Signal 3: Graph topology (structure)
        topology_sim = self._topology_similarity(new_entity, candidate)

        # Composite score
        composite = (
            self.string_weight * string_sim +
            self.semantic_weight * semantic_sim +
            self.topology_weight * topology_sim
        )

        # Decision logic
        if composite >= self.auto_merge_threshold:
            recommendation = "auto_merge"
        elif composite >= self.review_threshold:
            recommendation = "review"
        else:
            recommendation = "create_link"

        return EntityDuplicateCandidate(
            entity_a_id=new_entity.id,
            entity_b_id=candidate.id,
            string_similarity=string_sim,
            semantic_similarity=semantic_sim,
            topology_similarity=topology_sim,
            composite_score=composite,
            recommendation=recommendation
        )

    def _string_similarity(self, name_a: str, name_b: str) -> float:
        """
        Jaro-Winkler similarity (better than Levenshtein for short strings).
        Range: [0, 1]
        """
        # Normalize: lowercase, strip whitespace
        a = name_a.lower().strip()
        b = name_b.lower().strip()

        # Use built-in SequenceMatcher (Ratcliff-Obershelp algorithm)
        return SequenceMatcher(None, a, b).ratio()

    def _semantic_similarity(self, desc_a: str, desc_b: str) -> float:
        """
        Embedding-based cosine similarity.
        """
        embed_a = self.embedding_model.embed(desc_a)
        embed_b = self.embedding_model.embed(desc_b)

        # Cosine similarity: 1 - cosine_distance
        return 1 - cosine(embed_a, embed_b)

    def _topology_similarity(self, entity_a: Entity, entity_b: Entity) -> float:
        """
        Jaccard similarity of neighbors in KG.

        Logic: If two entities have highly overlapping neighborhoods,
        they likely represent the same concept.
        """
        neighbors_a = set(self.kg.get_neighbors(entity_a.id))
        neighbors_b = set(self.kg.get_neighbors(entity_b.id))

        if not neighbors_a and not neighbors_b:
            return 0.0  # Both isolated, can't determine from topology

        intersection = len(neighbors_a & neighbors_b)
        union = len(neighbors_a | neighbors_b)

        return intersection / union if union > 0 else 0.0

# Usage in batch pipeline
deduplicator = KGDeduplicator(embedding_model, kg)

for new_entity in batch_entities:
    candidates = deduplicator.find_duplicates(new_entity)

    for candidate in candidates:
        if candidate.recommendation == "auto_merge":
            kg.merge_entities(
                new_entity.id,
                candidate.entity_b_id,
                confidence=candidate.composite_score
            )
        elif candidate.recommendation == "review":
            review_queue.add({
                "entity_a": new_entity.id,
                "entity_b": candidate.entity_b_id,
                "score": candidate.composite_score,
                "reasons": {
                    "string": candidate.string_similarity,
                    "semantic": candidate.semantic_similarity,
                    "topology": candidate.topology_similarity
                }
            })
        else:  # create_link
            kg.add_alias(new_entity.id, candidate.entity_b_id)
```

### 2.2 KG Merge Operation with Provenance

```python
class KGMergeOperation:
    """
    Merge two entities while maintaining provenance and allowing rollback.
    """

    @dataclass
    class MergeEvent:
        source_entity_id: str
        target_entity_id: str
        timestamp: datetime
        merged_by: str  # "auto_dedup", "curator", etc.
        confidence: float
        reason: str
        edges_added: int
        edges_updated: int
        old_state: dict  # For rollback

    def merge_entities(
        self,
        source_id: str,
        target_id: str,
        merged_by: str = "auto_dedup",
        confidence: float = 0.95
    ) -> MergeEvent:
        """
        Merge source entity into target entity.

        Operations:
        1. Copy all edges from source to target
        2. Update all references (incoming/outgoing)
        3. Mark source as deprecated
        4. Log merge event
        """
        source = self.kg.get_entity(source_id)
        target = self.kg.get_entity(target_id)

        merge_event = self.MergeEvent(
            source_entity_id=source_id,
            target_entity_id=target_id,
            timestamp=datetime.now(),
            merged_by=merged_by,
            confidence=confidence,
            reason=f"Merged {source.name} into {target.name}",
            edges_added=0,
            edges_updated=0,
            old_state=self._capture_state(source_id, target_id)
        )

        # Step 1: Copy edges from source to target
        for edge in self.kg.get_outgoing_edges(source_id):
            new_edge = self.kg.add_edge(
                target_id,
                edge.target_id,
                edge.type,
                confidence=min(edge.confidence, confidence)
            )
            merge_event.edges_added += 1

        # Step 2: Update incoming edges
        for edge in self.kg.get_incoming_edges(source_id):
            self.kg.update_edge(
                edge.source_id,
                target_id,
                edge.type
            )
            merge_event.edges_updated += 1

        # Step 3: Mark source as deprecated
        self.kg.deprecate_entity(
            source_id,
            merged_into=target_id,
            timestamp=merge_event.timestamp
        )

        # Step 4: Log for audit trail
        self.merge_log.append(merge_event)

        return merge_event

    def _capture_state(self, entity_a_id: str, entity_b_id: str) -> dict:
        """Capture state before merge for potential rollback."""
        return {
            "entity_a": self.kg.get_entity(entity_a_id).__dict__,
            "entity_b": self.kg.get_entity(entity_b_id).__dict__,
            "edges_a": [e.__dict__ for e in self.kg.get_edges(entity_a_id)],
            "edges_b": [e.__dict__ for e in self.kg.get_edges(entity_b_id)]
        }
```

---

## 3. LEARNING PATH COMPUTATION

### 3.1 Path Recommendation Service

```python
from collections import deque, defaultdict
from typing import List, Tuple, Optional
import heapq

class LearningPathService:
    """
    Compute personalized learning paths using limited-depth BFS
    with caching and real-time adaptation.
    """

    def __init__(self, kg_graph, cache_layer):
        self.kg = kg_graph
        self.cache = cache_layer

        # Configuration
        self.depth_limit = 3  # 3-hop max for real-time
        self.batch_depth_limit = 10  # Full computation in batch
        self.cache_ttl_hot = 3600  # 1 hour
        self.cache_ttl_warm = 86400  # 24 hours

    def get_user_path_recommendation(
        self,
        user_id: str,
        goal_node_id: Optional[str] = None,
        depth_limit: int = None
    ) -> PathRecommendation:
        """
        Get next learning step for user.

        Algorithm:
        1. Check cache (3-level hierarchy)
        2. If miss: Compute path using BFS
        3. Update cache
        4. Return recommendation
        """
        cache_key = f"path:{user_id}:{goal_node_id or 'default'}"

        # Step 1: Check hot cache (1 hour TTL)
        cached = self.cache.get_hot(cache_key)
        if cached:
            self.cache.record_hit("hot")
            return cached

        # Step 2: Check warm cache (24 hour TTL)
        cached = self.cache.get_warm(cache_key)
        if cached:
            self.cache.record_hit("warm")
            # Refresh hot cache
            self.cache.set_hot(cache_key, cached, ttl=self.cache_ttl_hot)
            return cached

        # Step 3: Compute path
        self.cache.record_miss()

        user_current_node = self.kg.get_user_current_node(user_id)
        depth_limit = depth_limit or self.depth_limit

        # BFS with depth limit
        path = self._compute_path_bfs(
            user_current_node,
            goal_node_id,
            depth_limit
        )

        recommendation = PathRecommendation(
            user_id=user_id,
            current_node=user_current_node,
            goal_node=goal_node_id,
            full_path=path.full_path,
            next_steps=path.next_steps,
            confidence=path.confidence,
            computed_at=datetime.now()
        )

        # Step 4: Cache result (both hot and warm)
        self.cache.set_hot(cache_key, recommendation, ttl=self.cache_ttl_hot)
        self.cache.set_warm(cache_key, recommendation, ttl=self.cache_ttl_warm)

        return recommendation

    def _compute_path_bfs(
        self,
        start_node: str,
        goal_node: Optional[str],
        depth_limit: int
    ) -> PathComputationResult:
        """
        BFS-based path computation with depth limit.

        Returns:
        - full_path: Complete path from start to goal (if exists)
        - next_steps: Top 3 recommended next nodes
        - confidence: Path confidence score
        """
        visited = {start_node}
        queue = deque([(start_node, 0, [start_node])])  # (node, depth, path)

        goal_path = None
        step_counts = defaultdict(int)

        while queue:
            current, depth, path = queue.popleft()

            # Check if reached goal
            if current == goal_node:
                goal_path = path
                break

            # Don't exceed depth limit
            if depth >= depth_limit:
                continue

            # Explore neighbors
            neighbors = self.kg.get_next_topics(current)

            for neighbor_id, edge_score in neighbors:
                if neighbor_id not in visited:
                    visited.add(neighbor_id)
                    step_counts[neighbor_id] += 1
                    queue.append(
                        (neighbor_id, depth + 1, path + [neighbor_id])
                    )

        # Determine next steps (depth-1 nodes, highest score)
        next_step_candidates = []
        for neighbor_id, edge_score in self.kg.get_next_topics(start_node):
            next_step_candidates.append((neighbor_id, edge_score))

        next_steps = sorted(
            next_step_candidates,
            key=lambda x: -x[1]
        )[:3]  # Top 3

        # Compute confidence
        if goal_path:
            confidence = 0.95  # Path found
        else:
            confidence = 0.7  # Partial path (recommendations only)

        return PathComputationResult(
            full_path=goal_path,
            next_steps=[node_id for node_id, _ in next_steps],
            confidence=confidence
        )

    def invalidate_user_path_cache(self, user_id: str) -> None:
        """
        Invalidate cached paths when content changes.
        Called when:
        - User completes a short
        - KG is updated (new edges)
        - User's prerequisites change
        """
        # Invalidate both hot and warm caches
        patterns = [
            f"path:{user_id}:*"
        ]

        for pattern in patterns:
            self.cache.delete_pattern(pattern)

    def batch_compute_all_paths(self) -> None:
        """
        Nightly batch: Recompute all user paths for next day.

        Used to:
        1. Warm up caches
        2. Detect stale paths
        3. Aggregate metrics
        """
        users = self.kg.get_all_users()

        for user in users:
            path = self.get_user_path_recommendation(user.id)

            # Store in warm cache for tomorrow
            cache_key = f"path:{user.id}:default"
            self.cache.set_warm(
                cache_key,
                path,
                ttl=self.cache_ttl_warm
            )

        # Log completion
        self.logger.info(
            f"Batch path recomputation completed for {len(users)} users"
        )

@dataclass
class PathRecommendation:
    user_id: str
    current_node: str
    goal_node: Optional[str]
    full_path: Optional[List[str]]
    next_steps: List[str]
    confidence: float
    computed_at: datetime

@dataclass
class PathComputationResult:
    full_path: Optional[List[str]]
    next_steps: List[str]
    confidence: float
```

### 3.2 Cache Invalidation Strategy

```python
class CacheInvalidationManager:
    """
    Tag-based cache invalidation for learning paths.

    Pattern: When content changes, invalidate paths that depend on it.
    """

    def __init__(self, cache_layer):
        self.cache = cache_layer
        # Maps: path_key → set of node_ids it depends on
        self.path_dependencies = defaultdict(set)

    def record_path_computation(
        self,
        path_key: str,
        nodes_involved: List[str]
    ) -> None:
        """
        Record which nodes a cached path depends on.
        Called after computing each path.
        """
        self.path_dependencies[path_key] = set(nodes_involved)

    def on_node_changed(self, node_id: str) -> None:
        """
        Called when a node is added/modified/deleted.
        Invalidates all dependent caches.
        """
        affected_paths = []

        # Find all paths that depend on this node
        for path_key, dependencies in self.path_dependencies.items():
            if node_id in dependencies:
                affected_paths.append(path_key)

        # Invalidate affected caches
        for path_key in affected_paths:
            self.cache.delete(path_key)
            del self.path_dependencies[path_key]

        self.logger.info(
            f"Node {node_id} changed. Invalidated {len(affected_paths)} paths"
        )

    def on_edge_changed(self, source_id: str, target_id: str) -> None:
        """
        Called when a prerequisite edge is added/removed.
        More selective than node changes.
        """
        affected_paths = []

        # Find paths containing this edge
        for path_key, dependencies in self.path_dependencies.items():
            if source_id in dependencies and target_id in dependencies:
                affected_paths.append(path_key)

        for path_key in affected_paths:
            self.cache.delete(path_key)
            del self.path_dependencies[path_key]

        self.logger.info(
            f"Edge {source_id}→{target_id} changed. "
            f"Invalidated {len(affected_paths)} paths"
        )
```

---

## 4. HANDLING CONTENT DELETION & ADDITION

### 4.1 Content Deletion Handling

```python
class ContentDeletionManager:
    """
    Handle short deletion gracefully, finding alternatives and notifying users.
    """

    def __init__(self, kg, path_service):
        self.kg = kg
        self.path_service = path_service

    def delete_short(self, short_id: str) -> DeletionReport:
        """
        Delete short content and handle cascading effects.

        Strategy:
        1. Find all paths containing this short
        2. Compute alternative paths
        3. Notify affected users
        4. Update KG (mark as deprecated)
        """
        # Step 1: Find affected paths
        extract_node_id = self.kg.get_node_for_short(short_id)
        affected_users = self.kg.get_users_with_path_containing(extract_node_id)

        deletion_report = DeletionReport(
            short_id=short_id,
            extract_node_id=extract_node_id,
            affected_users=len(affected_users),
            rerouting_attempts=0,
            successful_reroutes=0,
            notification_sent=0
        )

        # Step 2: For each affected user, find alternative
        for user_id in affected_users:
            deletion_report.rerouting_attempts += 1

            # Get user's current path
            user_path = self.kg.get_user_path(user_id)

            # Find node before and after deleted node in path
            idx = user_path.index(extract_node_id)
            before_node = user_path[idx - 1]
            after_node = user_path[idx + 1] if idx + 1 < len(user_path) else None

            # Try rerouting: find path between before and after
            if after_node:
                alternative = self._find_alternative_path(
                    before_node,
                    after_node,
                    exclude_nodes={extract_node_id}
                )
            else:
                # No after node, recommend next topics
                alternative = None

            if alternative:
                # Update user's path
                new_path = (
                    user_path[:idx] +
                    alternative +
                    user_path[idx+1:]
                )
                self.kg.update_user_path(user_id, new_path)
                deletion_report.successful_reroutes += 1
            else:
                # No alternative found, notify user
                self._notify_user_path_broken(user_id, extract_node_id)

            deletion_report.notification_sent += 1

        # Step 3: Mark node as deprecated
        self.kg.deprecate_node(extract_node_id, reason="source_short_deleted")

        return deletion_report

    def _find_alternative_path(
        self,
        from_node: str,
        to_node: str,
        exclude_nodes: set = None,
        max_hops: int = 5
    ) -> Optional[List[str]]:
        """
        BFS to find alternative path between two nodes.
        """
        if exclude_nodes is None:
            exclude_nodes = set()

        visited = {from_node}
        queue = deque([(from_node, [from_node])])

        while queue:
            current, path = queue.popleft()

            if current == to_node:
                return path[1:]  # Return path excluding from_node

            if len(path) > max_hops:
                continue

            for neighbor in self.kg.get_next_topics(current):
                if neighbor not in visited and neighbor not in exclude_nodes:
                    visited.add(neighbor)
                    queue.append((neighbor, path + [neighbor]))

        return None  # No alternative found

    def _notify_user_path_broken(
        self,
        user_id: str,
        broken_node_id: str
    ) -> None:
        """
        Notify user that their path was affected by content deletion.
        """
        # Queue notification
        self.notification_queue.put({
            "user_id": user_id,
            "type": "path_updated",
            "message": (
                "A short in your learning path was updated. "
                "Check your updated recommendations."
            ),
            "action": "view_path"
        })

@dataclass
class DeletionReport:
    short_id: str
    extract_node_id: str
    affected_users: int
    rerouting_attempts: int
    successful_reroutes: int
    notification_sent: int
```

### 4.2 Content Addition Handling

```python
class ContentAdditionManager:
    """
    When new short is added, determine if it improves existing paths.
    """

    def __init__(self, kg, path_service):
        self.kg = kg
        self.path_service = path_service

    def short_added(self, short_id: str) -> AdditionReport:
        """
        Process new short addition.

        Check if new short improves any existing user paths.
        """
        # Step 1: Extract concepts from new short
        extract_nodes = self.kg.get_nodes_for_short(short_id)

        # Step 2: Find users whose paths could benefit
        affected_users = self.kg.find_users_with_path_gap(
            extract_nodes
        )

        addition_report = AdditionReport(
            short_id=short_id,
            extract_nodes=len(extract_nodes),
            potential_improvement_users=len(affected_users),
            improvements_offered=0,
            improvements_accepted=0
        )

        # Step 3: For each user, check if new path is better
        for user_id in affected_users:
            current_path = self.path_service.get_user_path_recommendation(user_id)

            # Compute alternative path using new short
            new_path = self._compute_path_with_new_short(
                user_id,
                current_path,
                short_id
            )

            if new_path and self._is_better_path(current_path, new_path):
                # Offer improvement
                self._offer_path_update(user_id, current_path, new_path)
                addition_report.improvements_offered += 1

        return addition_report

    def _compute_path_with_new_short(
        self,
        user_id: str,
        current_path: PathRecommendation,
        short_id: str
    ) -> Optional[PathRecommendation]:
        """
        Compute alternative path that includes new short.
        """
        new_nodes = self.kg.get_nodes_for_short(short_id)

        # Can we insert new_nodes into current_path?
        for i, node_id in enumerate(current_path.full_path):
            # Check if new node would fit here
            prev_node = current_path.full_path[i-1] if i > 0 else None
            next_node = current_path.full_path[i+1] if i < len(current_path.full_path) - 1 else None

            # Simple insertion check: prerequisites satisfied?
            for new_node in new_nodes:
                if self._prerequisites_satisfied(new_node, prev_node):
                    # Can insert here
                    new_path_list = (
                        current_path.full_path[:i] +
                        [new_node] +
                        current_path.full_path[i:]
                    )
                    return PathRecommendation(
                        user_id=user_id,
                        current_node=current_path.current_node,
                        goal_node=current_path.goal_node,
                        full_path=new_path_list,
                        next_steps=current_path.next_steps,
                        confidence=0.85,
                        computed_at=datetime.now()
                    )

        return None  # Can't improve path

    def _is_better_path(
        self,
        current: PathRecommendation,
        alternative: PathRecommendation
    ) -> bool:
        """
        Compare two paths using multiple criteria.
        """
        return (
            len(alternative.full_path) < len(current.full_path)  # Shorter
            and alternative.confidence >= current.confidence  # Not worse
        )

    def _offer_path_update(
        self,
        user_id: str,
        current: PathRecommendation,
        alternative: PathRecommendation
    ) -> None:
        """
        Notify user of better path option.
        """
        self.notification_queue.put({
            "user_id": user_id,
            "type": "path_improved",
            "message": "A better learning path is now available!",
            "action": "view_alternative_path",
            "current_path_length": len(current.full_path),
            "alternative_path_length": len(alternative.full_path)
        })

@dataclass
class AdditionReport:
    short_id: str
    extract_nodes: int
    potential_improvement_users: int
    improvements_offered: int
    improvements_accepted: int
```

---

## 5. METRICS & MONITORING

### 5.1 Key Performance Indicators (KPIs)

```python
class LearningPathMetrics:
    """
    Track KPIs for pipeline health and user experience.
    """

    # Cache Performance
    cache_hit_rate: float  # Target: >70%
    cache_eviction_rate: float  # Target: <5%
    average_path_computation_ms: float  # Target: <100ms

    # Content Quality
    entity_dedup_accuracy: float  # Target: >95%
    entity_precision: float  # Target: >90%
    entity_recall: float  # Target: >85%

    # User Experience
    path_completion_rate: float  # Target: >70%
    path_switch_rate: float  # % who accept new paths (Target: >20%)
    user_satisfaction: float  # Survey rating (Target: >4.0/5.0)

    # System Health
    kg_update_latency_p95: float  # ms (Target: <1000ms)
    path_invalidation_delay: float  # ms (Target: <500ms)

    @staticmethod
    def compute_cache_hit_rate(hits: int, misses: int) -> float:
        total = hits + misses
        return (hits / total) if total > 0 else 0.0

    @staticmethod
    def compute_path_completion_rate(
        completed: int,
        started: int
    ) -> float:
        return (completed / started) if started > 0 else 0.0
```

### 5.2 Monitoring & Alerting

```python
class PipelineMonitoring:
    """
    Real-time monitoring with alerting.
    """

    def __init__(self, metrics_client):
        self.metrics = metrics_client

    def log_path_computation(self, user_id: str, latency_ms: int):
        """Log path computation metric."""
        self.metrics.histogram(
            "learning_path.computation_time",
            latency_ms,
            tags={"user_id": user_id}
        )

        # Alert if slow
        if latency_ms > 200:
            self.metrics.increment(
                "learning_path.slow_computation_count",
                tags={"threshold": "200ms"}
            )

    def log_dedup_decision(self, decision: str, score: float):
        """Log entity deduplication decision."""
        self.metrics.histogram(
            "entity_dedup.score",
            score,
            tags={"decision": decision}
        )

    def log_cache_hit(self, cache_level: str):
        """Log cache hit for measurement."""
        self.metrics.increment(
            "cache.hit",
            tags={"level": cache_level}
        )
```

---

## 6. DEPLOYMENT CHECKLIST

### Pre-Deployment
- [ ] Deduplication algorithm tested on representative data
- [ ] Cache hit rates >60% in staging
- [ ] Path computation latency <150ms p95
- [ ] Entity extraction confidence >85% on sample shorts
- [ ] Rollback procedures documented and tested

### Rollout Strategy
- [ ] Day 1: Real-time preview layer (low risk)
- [ ] Day 2: Batch KG updates with manual review
- [ ] Day 3: Auto-merge threshold lowered (0.99 → 0.98)
- [ ] Week 1: Human review of dedup decisions
- [ ] Week 2: Path computation optimization
- [ ] Week 3: Full scale-out

### Monitoring During Rollout
- [ ] Cache hit rate trending upward
- [ ] Entity dedup accuracy confirmed >95%
- [ ] No cascading path invalidations
- [ ] User satisfaction metrics stable

---

## References

- Topological Sort Algorithms: O(V+E) complexity
- BFS Path Finding: Linear time, bounded by depth limit
- Jaccard Similarity: Effective for entity deduplication in KGs
- Tag-Based Cache Invalidation: Meta engineering blog
- Real-Time vs Batch Processing: Netflix case study