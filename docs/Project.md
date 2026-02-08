“Design and implement a Python‑based backend that uses ChromaDB, Google-GenAI, Gemini, and Firestore (Spark plan) to ingest, process, manage, and recommend multimedia notes and knowledge. You can have 3 firestore collections for now which are users, articles, notes (add more if really needed). Use a proper workflow and a modular design. Keep things simple and complete and secure. The system must:
1. **Ingest & Store Notes:**
   * Accept notes containing text, images, audio, links, or other media types via an API or Firestore listener.
   * Save raw notes to a Firestore collection named `notes`.
2. **Normalize & Extract Content:**
   * Use gemini for images, speech‑to‑text on audio, HTML parsing on links, and any other necessary metadata extraction.
   * Consolidate all extracted text and metadata into a clean, unified document for processing.
3. **Chunking & Deduplication:**
   * Split each note’s content into semantically coherent chunks.
   * For each chunk, query the ChromaDB vector store to detect overlap with existing embeddings.
   * Insert embeddings only for novel chunks; purge embeddings for removed or updated chunks to keep the store synchronized and prevent duplicates.
4. **Embedding Management:**
   * Use Gemini/Google GenAI to generate high‑quality embeddings for each new or modified chunk.
   * Maintain ChromaDB—self‑hosted on Cloud Run—so that updates and deletions in Firestore trigger corresponding vector operations.
5. **Summary Article Generation:**
   * For every newly added or significantly updated chunk, invoke Gemini to generate a concise, one‑paragraph summary that covers all the chunk’s information.
   * Ensure each summary is unique by checking semantic similarity against existing summaries in ChromaDB before creation.
6. **Article Storage & Citations:**
   * Persist each summary as a document in the Firestore `articles` collection, including:
     * The summary text.
     * A citation list linking back to source `note` IDs and chunk identifiers.
     * Metadata fields such as timestamp, embedding vector, and exploration tags.
7. **Lifecycle Consistency:**
   * On note edits or deletions, automatically update or remove corresponding embeddings and summary articles.
   * Guarantee no residual or duplicate knowledge remains across the vector store or article collection.
8. **User Modeling & Recommendation:**
   * Track per‑user reading history, including the last 10 read or skipped articles, overall engagement, interests, and inferred understanding levels.
   * Implement a recommendation engine—via Cloud Run—that scores unread articles by:
     * Semantic relevance to current reading context.
     * Alignment with the user’s profile (interests and capability).
     * Novelty relative to recent interactions.
   * Update a pointer in each user’s Firestore profile to the next best article.
9. **Exploration Hooks:**
   * For each generated article, call Gemini to produce 5–10 follow‑up questions or related topic suggestions.
   * Store these exploration prompts alongside the article to drive deeper learning paths.
10. **Entirely Free‑Tier:**
* Operate on Google Cloud’s Spark plan and free tier limits (Firestore, Cloud Functions, Cloud Run, Cloud Storage).
* Self‑host ChromaDB in a Cloud Run container using free vCPU‑seconds and Cloud Storage for persistence.
* Security rules and access controls on Firestore collections to ensure per-user data isolation.

I want to build a flutter app which is like a replica of inshorts. Users can specify interests like AI, maths, etc, can also specify website urls, newsletters redirection, clubs or groups subscriptions redirection and plenty of sources of information. The app will featch exisitng information and keep listening for new information on them. While this process keeps going on, the app will curate all the information in series of structured small 1 min read articles, each item will focus on the given concept and go indepth in it without overwhelming the user with a lot of information. The new information that is being listened in real-time can be kept on added to the current pile. Duplicacy is avoided, so if an article tells some information which is already covered in other articles then dont need to add this article or remove the exisitng articles and add this one. The user can mark the article as done once read, he can also skip it so, the article will come again later, he can also share or save it, etc. The content and curation adapts to user progress and interaction like if a user is quickly marking articles done then probably he knows all that so future related articles can be skipped or curated in one small article to reduce the user load, there could be multiple factors involved and various course of actions. Thoroughly research this context awareness and smart adaptability system. Research existing solutions, demands, requirements, challenges, gaps, features, etc. DO NOT worry about the code or technical implementation, just focus on the context awareness and smart learning adaptability system and article management or curation and other things. Consider all factors, courses of actions, features and a lot of other things.

Go over a lot of relevant/related research papers, technological advancements, existing solutions/technologies, followed standards/concepts/algorithms/methods/models, implemented systems, etc.
Also my app has the following additional feature. The user can keep on going to the next article, but he can also dive deeper into the current topic or level or go above a level. if he goes deeper in the topic right now, the other articles which were supposed to be next will come after all the articles related to the current topic has completed. the user can even midway go in a different articles level path. no matter what path the user follows in the interconnected web of articles, he ends up going over all the articles. also completition of some articles can automatically suggest completion of some other articles.

The navigation is more like traversing a web incorporating some hierarchy as well. Its like when you are on an article, you can dive deeper, go to next article, go up a single or multiple levels depending on if articles present, and many other options to traverse the web. even when going in one direction, you might have multiple articles to go to, the order or roadmap can be decided and automatically adjusted based on user understanding by the system or path followed till now, etc. Think of it like this, whenever a user reads an article or skips an article the whole subsequent roadmap can get modified or adjusted. the next articles can be decided by probability estimation or other ml or stats or other algorithms. Its like how LLMs predict next character taking the current state till now into account.
Taking into consideration your previous research, Research even more on this whole adaptable, curated, personalized, smart, contextual, etc system i am planning to create. Explore all possibilities, fields, directions, etc.

Based on your inputs and our discussions, the mobile application you envisioned is a sophisticated, Flutter-based educational platform designed to deliver concise, personalized learning experiences inspired by the Inshorts model but tailored for educational content. Its primary purpose is to curate 1-minute read articles from user-specified sources (e.g., websites, newsletters) and interests (e.g., AI, mathematics), providing a smart, adaptive system that evolves based on user interactions—such as marking articles as done, skipping, sharing, or saving them—while ensuring no duplicate content and offering real-time updates. The app features a unique, web-like navigation system that allows users to dive deeper into topics, progress to the next article, or ascend to higher levels, with a dynamic content roadmap that adjusts to ensure comprehensive coverage of material. Built with a Flutter frontend, it boasts a clean, card-based interface with interactive elements, dark mode, offline reading, and accessibility options, while the backend manages content fetching, summarization, and user data. Educational enhancements include quizzes, progress tracking, and personalized learning paths, making it a robust tool for self-directed learning. The app’s AI-driven, concise, and educational nature is reflected in potential names like "LearnShorts" or "AI Learn Clips." Key requirements include real-time content updates, duplicate avoidance, and a seamless, adaptive user experience across both frontend and backend systems.

For the survey of read-it-later, capture, and second-brain tools, see docs/RecordEverything.md.


# Backend Project Structure - Multimedia Knowledge Management System

## Root Directory Structure

```
multimedia-knowledge-backend/
├── README.md
├── requirements.txt
├── .env.example
├── .gitignore
├── Dockerfile
├── cloudbuild.yaml
├── main.py                          # FastAPI application entry point
├── config/
│   ├── __init__.py
│   ├── settings.py                  # Environment configuration
│   ├── firebase_config.py           # Firebase/Firestore setup
│   └── chroma_config.py             # ChromaDB configuration
├── app/
│   ├── __init__.py
│   ├── api/
│   │   ├── __init__.py
│   │   ├── routes/
│   │   │   ├── __init__.py
│   │   │   ├── notes.py             # Note ingestion endpoints
│   │   │   ├── articles.py          # Article retrieval endpoints
│   │   │   ├── users.py             # User management endpoints
│   │   │   └── recommendations.py   # Recommendation endpoints
│   │   ├── middleware/
│   │   │   ├── __init__.py
│   │   │   ├── auth.py              # Authentication middleware
│   │   │   ├── rate_limiting.py     # Rate limiting
│   │   │   └── cors.py              # CORS configuration
│   │   └── dependencies.py          # FastAPI dependencies
│   ├── models/
│   │   ├── __init__.py
│   │   ├── user.py                  # User data models
│   │   ├── note.py                  # Note data models
│   │   ├── article.py               # Article data models
│   │   ├── chunk.py                 # Chunk data models
│   │   └── recommendation.py        # Recommendation models
│   ├── services/
│   │   ├── __init__.py
│   │   ├── firestore/
│   │   │   ├── __init__.py
│   │   │   ├── base.py              # Base Firestore operations
│   │   │   ├── notes_service.py     # Notes collection operations
│   │   │   ├── articles_service.py  # Articles collection operations
│   │   │   └── users_service.py     # Users collection operations
│   │   ├── content_processing/
│   │   │   ├── __init__.py
│   │   │   ├── extractor.py         # Content extraction orchestrator
│   │   │   ├── image_processor.py   # Image content extraction
│   │   │   ├── audio_processor.py   # Audio to text conversion
│   │   │   ├── link_processor.py    # HTML/link content extraction
│   │   │   ├── text_processor.py    # Text normalization
│   │   │   └── chunker.py           # Content chunking logic
│   │   ├── vector_store/
│   │   │   ├── __init__.py
│   │   │   ├── chroma_client.py     # ChromaDB operations
│   │   │   ├── embeddings.py        # Embedding generation
│   │   │   ├── similarity.py        # Similarity checking
│   │   │   └── deduplication.py     # Duplicate detection
│   │   ├── ai_services/
│   │   │   ├── __init__.py
│   │   │   ├── gemini_client.py     # Gemini API wrapper
│   │   │   ├── summarizer.py        # Article summarization
│   │   │   ├── question_generator.py # Exploration questions
│   │   │   └── content_analyzer.py  # Content analysis
│   │   ├── recommendation/
│   │   │   ├── __init__.py
│   │   │   ├── engine.py            # Recommendation engine
│   │   │   ├── user_profiler.py     # User interest profiling
│   │   │   ├── scoring.py           # Article scoring logic
│   │   │   └── context_analyzer.py  # Reading context analysis
│   │   └── lifecycle/
│   │       ├── __init__.py
│   │       ├── note_processor.py    # Note lifecycle management
│   │       ├── article_manager.py   # Article lifecycle management
│   │       └── cleanup_service.py   # Cleanup operations
│   ├── utils/
│   │   ├── __init__.py
│   │   ├── logger.py                # Logging configuration
│   │   ├── validators.py            # Input validation
│   │   ├── security.py              # Security utilities
│   │   ├── cache.py                 # Caching utilities
│   │   └── helpers.py               # General helpers
│   └── background_tasks/
│       ├── __init__.py
│       ├── firestore_listeners.py   # Firestore change listeners
│       ├── batch_processor.py       # Batch processing tasks
│       └── scheduler.py             # Task scheduling
├── cloud_run/
│   ├── chroma_service/
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   ├── main.py                  # ChromaDB service
│   │   └── config.py
│   └── recommendation_service/
│       ├── Dockerfile
│       ├── requirements.txt
│       ├── main.py                  # Recommendation service
│       └── config.py
├── cloud_functions/
│   ├── note_ingestion/
│   │   ├── main.py                  # Note ingestion trigger
│   │   └── requirements.txt
│   ├── article_generation/
│   │   ├── main.py                  # Article generation trigger
│   │   └── requirements.txt
│   └── recommendation_update/
│       ├── main.py                  # Recommendation update trigger
│       └── requirements.txt
├── security/
│   ├── firestore_rules.txt          # Firestore security rules
│   ├── cloud_storage_rules.txt      # Cloud Storage security rules
│   └── iam_policies.json            # IAM policy configurations
├── tests/
│   ├── __init__.py
│   ├── unit/
│   │   ├── test_services/
│   │   ├── test_models/
│   │   └── test_utils/
│   ├── integration/
│   │   ├── test_api/
│   │   ├── test_firestore/
│   │   └── test_chroma/
│   └── fixtures/
│       ├── sample_notes.json
│       ├── sample_users.json
│       └── sample_articles.json
├── scripts/
│   ├── setup_environment.py         # Environment setup script
│   ├── deploy.sh                    # Deployment script
│   ├── backup_data.py               # Data backup script
│   └── migrate_data.py              # Data migration script
└── docs/
    ├── api_documentation.md
    ├── deployment_guide.md
    ├── architecture_overview.md
    └── security_guidelines.md
```

## Key Components Breakdown

### 2. **Cloud Run Services (`cloud_run/`)**

#### **ChromaDB Service**
- Self-hosted ChromaDB instance
- Persistent storage via Cloud Storage
- REST API for vector operations
- Automatic scaling within free tier limits

#### **Recommendation Service**
- Dedicated recommendation engine
- User profiling and scoring algorithms
- Context-aware article suggestions
- Batch processing capabilities

### 3. **Cloud Functions (`cloud_functions/`)**

#### **Event-Driven Processing**
- **Note Ingestion**: Triggered on Firestore note creation/update
- **Article Generation**: Triggered on chunk processing completion
- **Recommendation Update**: Triggered on user interaction changes

### 6. **Background Tasks (`app/background_tasks/`)**

#### **Firestore Listeners**
- Real-time change detection
- Automatic cleanup triggers
- Batch processing coordination

### 7. **Utilities (`app/utils/`)**

#### **Cross-Cutting Concerns**
- Logging and monitoring
- Input validation and sanitization
- Security utilities
- Caching mechanisms

## Data Flow Architecture

### 1. **Note Ingestion Flow**
```
API Request → Validation → Firestore (notes) → Cloud Function Trigger → 
Content Processing → Chunking → Embedding Generation → ChromaDB Storage → 
Article Generation → Firestore (articles) → Recommendation Update
```

### 2. **User Interaction Flow**
```
User Action → Firestore (users) → Reading History Update → 
Recommendation Engine → Scoring Algorithm → Next Article Pointer Update
```

### 3. **Lifecycle Management Flow**
```
Note Update/Delete → Firestore Trigger → Cleanup Service → 
ChromaDB Update → Article Update/Delete → Recommendation Refresh
```

### **Privacy**
- User data isolation
- Anonymization of analytics data
- GDPR compliance considerations
- Data retention policies

**Project Requirements:**

Create a TypeScript-based React browser extension with Firebase backend that enables users to capture, highlight, and organize web content across all major browsers (Chrome, Firefox, Safari, Edge).

**Core Architecture:**

- Frontend: React 19+ with TypeScript, CSS modules/styled-components
- Backend: Firebase (Firestore, Authentication, Storage, Functions)
- Extension: Manifest V3 compatible
- Build system: Vite with cross-browser compatibility

**Essential Features to Implement:**

**Content Capture System:**

- Save entire web pages (HTML + assets)
- Save selected text with context preservation
- Extract main content only (article extraction)
- Universal website compatibility
- RSS feed integration and monitoring
- Twitter thread capture with threading preservation
- Drag-and-drop file upload with multiple format support
- Mobile share sheet integration
- Browser extension quick-save functionality

**Advanced Highlighting System:**

- Real-time web page highlighting with persistence
- Multi-device highlight synchronization
- Audio-based highlighting (AirPods integration)
- Highlight management dashboard
- Support for text, links, images, and multimedia content
- Highlight removal and editing capabilities
- Manual highlight input with custom notes

**Template and Metadata System:**

- Custom template creation with visual editor
- Schema.org data extraction engine
- OpenGraph metadata parsing
- Automatic template triggers based on URL patterns
- Website-specific template rules
- Structured data extraction and storage
- Template matching algorithm

**Organization and Search:**

- Hierarchical tag management system
- Hierarchical note organization and management
- Full-text search with advanced filtering
- Custom filtered views and saved searches
- Annotation system with rich text support
- Content categorization and organization
- Speech-to-text note capture integration
- AI-powered auto-highlighting of key passages

**User Experience:**

- Customizable keyboard shortcuts and hotkeys
- Context menu integration (right-click)
- Collapsible sidebar for quick access
- Multiple import/export formats (JSON, CSV, PDF, etc.)
- Cross-platform synchronization
- Responsive design for all screen sizes

**Technical Specifications:**

- Implement proper error handling and offline functionality
- Ensure GDPR compliance and data privacy
- Optimize for performance with lazy loading
- Include comprehensive unit and integration tests
- Implement proper security measures for data handling

**Deliverables:**

1. Complete source code with proper TypeScript typing
2. Firebase configuration and security rules
3. Cross-browser extension manifests
4. Comprehensive documentation and setup instructions
5. Testing suite with coverage reports
6. Deployment scripts for multiple browser stores

**Constraints:**

- Must work offline with sync when online
- Maximum 50MB extension size
- Support for 10,000+ saved items per user
- Response time under 200ms for search operations
- Compatible with Chrome 88+, Firefox 78+, Safari 14+, Edge 88+

# SkillZhorts AI Development Guide

## Architecture & Design Philosophy

This is a **production-ready Flutter news application** built on the [Flutter News Toolkit](https://flutter.github.io/news_toolkit). The architecture emphasizes:

- **Separation of Concerns**: Clear boundaries between UI, business logic, and data
- **Testability First**: 100% test coverage requirement enforced by CI
- **Modular Packages**: Reusable, independently testable components
- **Declarative UI**: Flutter widgets + Bloc state management
- **Type Safety**: Generated code for assets, JSON serialization, routing

### Project Structure

```
skill_zhorts/
├── lib/                    # Feature modules (feed, article, search, etc.)
│   ├── <feature>/
│   │   ├── bloc/          # Business logic (events, states, blocs)
│   │   ├── view/          # Pages and main UI screens
│   │   └── widgets/       # Reusable UI components
│   └── main/              # App entry points and bootstrap
├── packages/              # 19 independent packages
│   ├── *_repository/      # Data layer (API calls, business logic)
│   ├── *_client/          # External service wrappers
│   ├── app_ui/            # Design system (themes, widgets, assets)
│   └── news_blocks_ui/    # Content rendering components
├── api/                   # Dart Frog backend (development/testing)
└── test/                  # Mirrors lib/ structure
    └── helpers/           # Test utilities (pump_app, mocks)
```

## Core Architectural Concepts

### 1. NewsBlocks Content System

**Design Philosophy**: Articles are composed of **heterogeneous content blocks** rather than raw HTML/markdown. This enables rich, interactive, platform-native rendering.

**NewsBlock Types**:
- `PostLargeBlock`, `PostMediumBlock`, `PostSmallBlock` - Article previews
- `ImageBlock`, `VideoBlock` - Media content
- `HtmlBlock`, `TextCaptionBlock` - Text/HTML
- `SlideshowBlock`, `SlideBlock` - Image galleries
- `NewsletterBlock` - Inline newsletter signup
- `BannerAdBlock` - Advertisement placement
- `DividerHorizontalBlock`, `SpacerBlock` - Layout spacing
- `PostGridGroupBlock` - Grid layouts

**Flow**: API returns `List<NewsBlock>` → UI renders via `ArticleContentItem` widget → Each block type has specialized UI in `news_blocks_ui`

**Why**: Decouples content structure from presentation, enables A/B testing layouts, supports ads/paywalls insertion

### 2. State Management: Bloc Pattern

**Core Principle**: Every feature has a Bloc that manages state through events/states (immutable, testable, reactive)

**Bloc Variants**:
- **Regular Bloc**: Ephemeral state (e.g., `LoginBloc`, `SearchBloc`)
- **HydratedBloc**: Persisted state to disk (e.g., `FeedBloc`, `CategoriesBloc`, `ArticleBloc`)
  - Uses `HydratedStorage` initialized in bootstrap
  - State survives app restarts (offline-first)

**Concurrency Control** (`bloc_concurrency`):
- `sequential()` - Process events one-by-one (feed loading)
- `droppable()` - Ignore events while processing (refresh button spam)

**Example Pattern**:
```dart
class FeedBloc extends HydratedBloc<FeedEvent, FeedState> {
  on<FeedRequested>(_onFeedRequested, transformer: sequential());
  on<FeedRefreshRequested>(_onFeedRefresh, transformer: droppable());
}
```

### 3. App-Level State Flow

**AppBloc** manages top-level application state:

```
AppStatus.onboardingRequired  (new users)
    ↓ (complete onboarding)
AppStatus.unauthenticated    (anonymous browsing)
    ↓ (login via email link)
AppStatus.authenticated      (logged-in user)
```

**Navigation**: `flow_builder` listens to `AppStatus` and rebuilds routes declaratively
- Onboarding → `OnboardingPage`
- Unauthenticated/Authenticated → `HomePage` (with conditional UI)

**User Subscription State**: `AppState.isUserSubscribed` drives premium features (ad removal, content access)

### 4. Dependency Injection

**Pattern**: Constructor injection with `RepositoryProvider` wrapping
- Repositories injected at app root ([app.dart](lib/app/view/app.dart))
- Blocs created via `BlocProvider` and pull dependencies from context
- No service locators/singletons

**Initialization Order** ([bootstrap.dart](lib/main/bootstrap/bootstrap.dart)):
1. Firebase (Auth, Crashlytics, Messaging, Dynamic Links)
2. HydratedBloc storage
3. Repository instances (User, News, Notifications, etc.)
4. App widget with providers

### 5. Asset Generation

**flutter_gen**: Auto-generates type-safe asset classes
```dart
// ✅ Correct
Assets.images.logoDark.image()

// ❌ Never use raw strings
Image.asset('assets/images/logo_dark.png')
```

Regenerate: `flutter pub get` (runs automatically)

## Feature Modules Deep Dive

### Authentication & User Management

**Magic Link Email Login**:
- User enters email → `UserRepository.sendLoginEmailLink()` → Firebase sends email with Dynamic Link
- `LoginWithEmailLinkBloc` listens to `incomingEmailLinks` stream
- On link open: Extract email from `continueUrl` param → `logInWithEmailLink()` → User authenticated

**User Model**:
- `User.anonymous` - Default state
- `User.isNewUser` - Triggers onboarding
- `User.subscriptionPlan` - None/Basic/Premium (drives paywall logic)

**UserRepository**: Bridges Firebase Auth and backend API
- Stream-based: `userRepository.user` emits on auth changes
- Persists user data to local storage ([UserStorage](packages/user_repository/lib/src/user_storage.dart))

### Onboarding Flow

**Purpose**: First-run experience for new users (permissions, preferences)

**Steps**:
1. Ad tracking consent (`AdsConsentClient.requestConsent()`)
2. Push notification permissions (`NotificationsRepository.toggleNotifications()`)
3. Category preferences (handled in main feed)

**Completion**: Fires `AppOnboardingCompleted` event → `AppStatus` transitions to `authenticated`

### Feed & Categories System

**Architecture**: Category-based content discovery
- `CategoriesBloc` - Fetches/manages available categories (persisted)
- `FeedBloc` - Loads content blocks per category (persisted, paginated)

**Pagination**:
```dart
_newsRepository.getFeed(
  category: category,
  offset: categoryFeed.length,  // Current item count
)
```

**HydratedBloc Benefit**: Feed state persists across app restarts → instant display, background refresh

**Feed Refresh**: `FeedRefreshRequested` with `droppable()` prevents duplicate requests

### Article Viewing

**ArticleBloc**:
- Fetches full article content (`List<NewsBlock>`)
- Tracks view count increment
- Manages related articles
- Premium content gating (checks `isUserSubscribed`)

**Rendering**: `ArticleContentItem` widget switches on block type → renders specialized UI from `news_blocks_ui`

### Search System

**SearchBloc**: Real-time search with debouncing
- Popular searches (pre-fetched)
- Relevant search (query-based, paginated)

**Pattern**: Separate events for popular vs. query-based search

### Ads Integration

**FullScreenAdsBloc**:
- Pre-loads interstitial and rewarded ads
- Retry policy with exponential backoff (`AdsRetryPolicy`)
- Platform-specific ad unit IDs (iOS/Android)

**Ad Types**:
- Banner ads (in content blocks)
- Interstitial ads (between content)
- Rewarded ads (unlock premium features temporarily)

**Ad Consent**: Managed via `AdsConsentClient` (GDPR/CCPA compliance)

### Subscriptions & In-App Purchases

**InAppPurchaseRepository**:
- Wraps platform `in_app_purchase` package
- Integrates with backend for subscription verification
- Handles purchase restoration
- Manages subscription status sync

**Flow**: User selects plan → Purchase → Backend verification → User.subscriptionPlan updated → Premium features unlocked

### Notifications System

**NotificationsRepository**:
- Push notification registration (Firebase Messaging)
- Category-based preferences (e.g., notifications for specific news categories)
- Deep link handling (notification tap → article)

**Permissions**: Requested during onboarding, can be changed in settings

### Analytics & Tracking

**AnalyticsBloc**:
- Global event tracking (no UI)
- Listens to `UserRepository.user` → sets userId in Firebase Analytics
- Events dispatched via `TrackAnalyticsEvent`

**AppBlocObserver**: Automatically logs bloc events/states for debugging and analytics

## Data Layer Architecture

### Repository Pattern

**Responsibilities**:
- Abstract data sources (API, local storage, platform services)
- Handle errors → convert to domain-specific exceptions
- Return domain models (not DTOs)

**Key Repositories**:
- `NewsRepository` - Articles, feed, categories, search
- `UserRepository` - Authentication, user profile
- `ArticleRepository` - Full article content, reading history
- `NotificationsRepository` - Push tokens, preferences
- `InAppPurchaseRepository` - Subscription management

**Error Handling**: Custom exception hierarchy (e.g., `GetFeedFailure`, `LoginFailure`)

### API Client Integration

**SkillZhortsApiClient** ([api/lib/client.dart](api/lib/client.dart)):
- REST API wrapper
- Token-based authentication (`tokenProvider`)
- Separate endpoints for development (localhost) and production

**API Models**: Shared between backend (`api/`) and client (`lib/`) via `news_blocks` package

### Storage Patterns

**PersistentStorage**: Wraps `SharedPreferences` for key-value storage
**SecureStorage**: Wraps `flutter_secure_storage` for sensitive data (tokens)
**HydratedStorage**: Bloc state persistence (JSON serialization)

### Client Abstractions

**Pattern**: Wrap external packages in client interfaces for testability
- `AuthenticationClient` → wraps Firebase Auth
- `NotificationsClient` → wraps Firebase Messaging
- `DeepLinkClient` → wraps Firebase Dynamic Links
- `PermissionClient` → wraps permission_handler

**Benefit**: Easy to mock in tests, can swap implementations

## Build Flavors & Environments

### Development Flavor

**Entry**: `lib/main/main_development.dart`

**Configuration**:
- API: `SkillZhortsApiClient.localhost` (local Dart Frog server)
- App Name: "SkillZhorts [DEV]"
- Bundle ID: `com.inventak.skillzhorts.dev`
- Debug mode: Clears HydratedBloc storage on start

**Run**: `flutter run -t lib/main/main_development.dart`

### Production Flavor

**Entry**: `lib/main/main_production.dart`

**Configuration**:
- API: `SkillZhortsApiClient` (production URL)
- App Name: "SkillZhorts"
- Bundle ID: `com.inventak.skillzhorts`
- Release mode: Preserves state

**Why Flavors**: Enables safe development without affecting production data/analytics

## Integration Points & Cross-Cutting Concerns

### Firebase Services

**Initialized in Bootstrap**:
1. **Firebase Core** - Foundation
2. **Firebase Auth** - User authentication (email link)
3. **Firebase Dynamic Links** - Deep linking for email authentication (deprecated but required)
4. **Firebase Crashlytics** - Crash reporting (production)
5. **Firebase Analytics** - Event tracking
6. **Firebase Messaging** - Push notifications

**Error Handling**: `FlutterError.onError` → Crashlytics

### Deep Linking

**Use Cases**:
1. Email login magic links (continueUrl with email param)
2. Push notification deep links (open specific article)
3. Share links (article URLs)

**DeepLinkService**: Centralizes link parsing and routing

## Comprehensive Frontend Features and Functionalities

### Core Features

1. **Article Feed / Main Screen**

   - Displays a card-based list of articles or the current article.
   - Swipe gestures or buttons for navigation (e.g., next, previous).
   - Pull-to-refresh for manual updates.
   - Visual indicators for new or unread articles.

2. **Article Detail View**

   - Shows title, content (text, images, videos), and source information.
   - Interaction buttons: mark as done, skip, share, save.
   - Dynamic navigation buttons: dive deeper, go to next, go up a level, or related articles, based on the article’s position in the graph.
   - Supports summaries or full articles based on backend input.

3. **Dynamic Navigation System**

   - Web-like navigation with a graph-based structure, allowing users to traverse articles hierarchically or laterally.
   - Buttons or gestures for “Dive Deeper” (subtopics), “Go Up” (broader topics), “Next,” or “Related” articles.
   - Adaptive roadmap updates based on user interactions (e.g., marking as done adjusts future articles).
   - Ensures all articles are eventually covered through graph traversal.

4. **Interest Selection**

   - Screen with checkboxes or toggles for selecting topics (e.g., AI, mathematics).
   - Searchable list for easy topic discovery.

5. **Source Selection**

   - Form to input URLs or select from predefined sources (e.g., news websites, newsletters).
   - Validation for URL formats and source availability.

6. **Search Functionality**

   - Search bar for finding articles by keyword or topic.
   - List view for search results, with filters for relevance or recency.

7. **Settings**

   - Options for dark mode, font size adjustment, notifications, and language selection.
   - Manage interests and sources from the settings screen.

### Additional Features

 8. **Dark Mode**

    - Toggle between light and dark themes for better readability.

 9. **Font Size Adjustment**

    - Slider or buttons to adjust text size, applied to article content.

10. **Offline Reading**

    - Cache articles locally using Hive or SQLite for offline access.
    - Indicator for offline mode.

11. **Notifications**

    - Push notifications for new articles or updates, configurable in settings.
    - Subtle in-app notifications for real-time updates.

12. **Bookmarks**

    - Save articles for later reading, accessible via a dedicated screen.

13. **Reading History**

    - Display previously read articles with timestamps and topics.

14. **Social Sharing**

    - Share articles via social media, email, or messaging apps using Flutter’s share_plus package.

15. **Text-to-Speech**

    - Option to listen to articles using a text-to-speech plugin (e.g., flutter_tts).

16. **Multilingual Support**

    - Language selection for UI and article content (if supported by backend).

17. **Accessibility Features**

    - Semantic labels for screen readers.
    - High-contrast themes and adjustable text sizes.
    - Gesture navigation for accessibility.

18. **Onboarding Tutorial**

    - Interactive guide for new users, explaining navigation and features.

19. **Error Handling**

    - Display user-friendly messages for network errors or content unavailability.
    - Fallback to offline content when applicable.

20. **Responsive Design**

    - Adaptive layouts using LayoutBuilder and MediaQuery for phones, tablets, and web.
    - Support for portrait and landscape orientations.

21. **Performance Optimizations**

    - Use CachedNetworkImage ([pub.dev](https://pub.dev/packages/cached_network_image)) for efficient image loading.
    - Lazy loading for article lists to improve scrolling performance.
    - Smooth animations using PageRouteBuilder or Hero widgets.

22. **User Progress Tracking**

    - Visual indicators (e.g., progress bars, badges) for read/unread articles.
    - Highlight completed topics or prerequisites.

## Implementation Considerations

### Content Rendering

- **Text and Images**: Use Text and CachedNetworkImage for efficient rendering.
- **Videos**: Integrate video_player or chewie ([pub.dev](https://pub.dev/packages/chewie)) for video content.
- **HTML Content**: Parse HTML using flutter_html if needed ([pub.dev](https://pub.dev/packages/flutter_html)).

### Navigation Logic

- Model articles as nodes in a directed acyclic graph (DAG) with edges for relationships (deeper, broader, related).
- Use Riverpod to track the current article and available navigation options.
- Dynamically generate navigation buttons based on the article’s connections.
- Ensure all articles are reachable by maintaining a connected graph and prioritizing unread articles.

### UX Enhancements

- **Gestures**: Optional swipe gestures (e.g., left for next, up for deeper) with clear visual cues.
- **Animations**: Smooth transitions between articles to enhance engagement.
- **Feedback**: Haptic feedback or visual indicators for user actions (e.g., marking as done).