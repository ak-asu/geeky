# Geeky — Project Proposal

**An Adaptive Educational Platform That Turns Your Notes Into a Personalized Learning Experience**

---

## 1. Introduction

Geeky is a Flutter-based adaptive educational platform for self-directed learners. The core idea: take whatever a user reads, watches, listens to, or captures — from any app on their phone — and turn it into bite-sized learning articles ("Shorts"), organized in a Knowledge Graph, and served through an adaptive engine that continuously reorders the roadmap based on how the user interacts.

This sits at the intersection of personal knowledge management and adaptive tutoring — a space that, as our research shows, no existing product occupies well. Note-taking apps (Notion, Obsidian) organize but don't teach. Learning apps (Khan Academy, Anki) teach but don't ingest your content. Geeky does both.

This proposal covers the research behind the design, how the platform leverages phone-native capabilities, the deliverables with phased milestones, and visual diagrams of each major subsystem.

### The Problem

Modern learners face five compounding problems:

1. **Content Scatter** — Material is spread across YouTube, LinkedIn, Twitter, PDFs, podcasts, and newsletters. No single tool synthesizes all of it.
2. **Information Overload** — Without curation, learners drown in duplicate content, content too easy to be useful, or content too advanced to absorb.
3. **Passive Consumption** — Platforms optimize for watch time, not retention. Reading an article is not the same as learning from it.
4. **No Adaptive Pathways** — Self-directed learners get no guidance on what to study next, what to review, or what gaps exist.
5. **Retention Decay** — Without spaced repetition, most information is forgotten within days.

Geeky addresses all five with a single, cohesive platform that captures content from the user's existing workflow, processes it into structured knowledge, and serves it back adaptively.

---

## 2. Research Foundations

Our design decisions are backed by a deep research phase documented across two internal reports (RESEARCH.md and RESEARCH_ANALYSIS.md, totaling ~1,600 lines of analysis). This section distills the key findings.

### 2.1 Adaptive Learning Systems

Geeky's personalization draws from **Intelligent Tutoring Systems (ITS)** — a well-studied four-component architecture:

| ITS Component | Geeky Equivalent |
|--------------|-----------------|
| Domain Model | Knowledge Graph of Shorts and Concepts |
| Student Model | User Profile: familiarity scores, BKT parameters, interaction history |
| Tutoring Model | Adaptive recommendation engine with multi-factor scoring |
| Interface Model | Swipe-based Flutter UI with gesture navigation |

We studied commercial platforms that validate our approach: **ALEKS** (based on Knowledge Space Theory) confirms knowledge is a web, not a sequence — learners navigate it differently. **Khan Academy** demonstrates DAG prerequisites with mastery gates work at scale, with per-student customization driven by MAP Growth scores. **Coursera** validates meta-path-guided graph convolutions for prerequisite modeling, along with weak concept mining that simplifies paths based on learner error rates. **Dreambox** shows that millions of personalized learning paths are achievable with real-time adaptation.

**Bayesian Knowledge Tracing (BKT)**, a hidden Markov model tracking four parameters per concept (prior knowledge, learning probability, slip, guess), forms our per-concept mastery model. BKT is updated on every quiz result, interaction speed, and skip pattern — producing a continuously refined estimate of what the user actually knows.

### 2.2 Knowledge Graphs & Entity Resolution

We surveyed **Microsoft GraphRAG** (batch extraction, hierarchical summarization), **Graphiti/Zep AI** (real-time incremental KG evolution with temporal context), and **Neo4j's LLM KG Builder** (entity extraction + graph enhancement + duplicate merging). The clear recommendation: a **hybrid real-time + batch approach** — quick entity extraction on ingestion for immediate preview, with full NER/dedup/reconciliation deferred to batch windows.

For entity deduplication, a **composite scoring model** combining string similarity (0.3), semantic embedding similarity (0.5), and graph topology similarity (0.2) determines auto-merge (>0.95), review queue (0.80–0.95), or alias creation (<0.80).

### 2.3 Content Processing Pipelines

We evaluated chunking strategies: proposition-based (high precision, expensive), semantic clustering (good for multi-topic docs), and fixed-size with sentence boundaries (simple, fast, sufficient for single-concept content). We selected the latter with hierarchical fallbacks for complex documents. For summarization, Gemini API with retrieval grounding and post-generation consistency checks minimizes hallucination while keeping outputs to ~150–250 words.

### 2.4 Spaced Repetition

**FSRS** (Free Spaced Repetition Scheduler) was selected over SM-2. With 21 trainable parameters and per-user optimization, FSRS achieves **20–30% fewer reviews** for the same retention rate, targeting 90% recall at review time.

### 2.5 Recommendation Engines

Our research compared five recommendation paradigms for educational content:

| Approach | Mechanism | Explainability | Best For |
|----------|-----------|----------------|----------|
| Path-Based | Prerequisite chains | High | Structured curricula |
| Graph-Based (GNN) | Message passing on KG | Medium | Rich relationships |
| Matrix Factorization | User-item embeddings | Low | Cold-start mitigation |
| Collaborative Filtering | User similarity | Medium | Implicit feedback |
| Hybrid | Combined signals | High | Production systems |

We selected a **hybrid approach**: path-based reasoning from the KG (prerequisite traversal, topological ordering), multi-factor scoring (40% relevance + 30% capability + 30% novelty), contextual bandits for exploration/exploitation balance, and BKT for difficulty calibration. Netflix's architecture informed our caching strategy: real-time computation for active users, batch pre-computation off-peak, three-tier cache (hot/warm/cold) with event-based invalidation.

### 2.6 Retrieval-Augmented Generation (RAG)

The RAG pipeline powers natural-language Q&A over the user's knowledge base. Best practices from production systems inform our design: hybrid retrieval (dense ChromaDB vectors + sparse BM25 keywords), cross-encoder reranking (BGE-Reranker for joint query-document scoring), MMR diversification (lambda ~0.7 balances relevance vs. redundancy), and a staged context compression pipeline (quality filter, sentence dedup, relevance scoring, token budgeting). Task-specific retrieval profiles vary parameters by output type — Q&A uses high precision, flashcards use high coverage, mind maps use maximum diversity.

### 2.7 Deduplication

A four-stage pipeline: (1) exact hash of canonicalized text, (2) near-duplicate via MinHash/LSH, (3) semantic similarity >= 0.85 against ChromaDB, (4) cross-modal detection across media types. Soft deduplication (downweighting, not deleting) preserves source diversity. Bloom filters handle streaming ingestion bursts.

---

## 3. Platform Overview

**Three pillars:**

1. **Content Ingestion** — Accept multimedia from share intents, uploads, URLs, RSS, and newsletters. Extract knowledge via Gemini. Distill into Shorts (~1 min reads).
2. **Knowledge Organization** — Organize Shorts in a Knowledge Graph with hierarchical/lateral relationships and Modules. Enable dive-deeper/go-up/next/related navigation.
3. **Adaptive Learning** — Model user knowledge with BKT, reorder roadmap after every interaction, use FSRS for retention, generate adaptive quizzes.

**Stack:** Flutter + Riverpod 3.0 (frontend), FastAPI + NetworkX (backend on Cloud Run), ChromaDB (vectors on Cloud Run), Firebase (Auth, Firestore, Storage, FCM, Cloud Functions), Gemini API (AI).

**Key packages (Flutter):** flutter_riverpod, go_router, drift, dio, retrofit, markdown_widget, fl_chart, graphview, flutter_animate, cached_network_image, flex_color_scheme, receive_sharing_intent, share_plus, flutter_tts, connectivity_plus, file_picker, firebase_messaging.

**Key packages (Python):** FastAPI, py-fsrs, chromadb, networkx, pydantic, beautifulsoup4, pillow, bleach.

---

## 4. Phone-Specific Features & Native Integrations

This is not a web app ported to mobile. Geeky is designed from the ground up to take advantage of what a phone can do — its share system, sensors, notifications, camera, microphone, local storage, and native billing.

### 4.1 OS Share Sheet (receive_sharing_intent)

The most important phone integration. Users share content from YouTube, LinkedIn, Twitter, Chrome, or any app directly to Geeky via the system share sheet. Geeky accepts text, URLs, images, and files. On Android it registers for all supported MIME types; on iOS it integrates with the Share Extension. This turns every app into a content source without changing reading habits.

### 4.2 Push Notifications (FCM)

Firebase Cloud Messaging powers review reminders (FSRS intervals), streak alerts, new content alerts, and achievement notifications. Every notification supports **deep linking** — tapping opens the exact Short, quiz, or review screen. Preferences are configurable per-topic, per-source, with frequency controls and quiet hours.

### 4.3 Text-to-Speech (flutter_tts)

Two audio modes: (1) per-Short TTS via the device's native engine — instant, offline, accessible; (2) server-generated podcast-style audio overviews for Modules, streamed from Cloud Storage. Transforms commuting and exercise time into learning time.

### 4.4 Camera, Microphone & File Access (file_picker)

Capture whiteboard photos (Gemini Vision OCR), record voice memos (Speech-to-Text), upload PDFs/DOCX. Export data as JSON/CSV for portability. Manage local cache size. Download Modules for offline study.

### 4.5 Deep Linking & App Links

Routes like `geeky://short/{id}`, `geeky://module/{id}`, `geeky://quiz/{id}` open specific screens. Used for sharing Shorts with friends, notification deep links, and web-to-app handoff. GoRouter resolves routes with auth guards.

### 4.6 Offline-First Architecture (Drift + connectivity_plus)

Reads hit local SQLite (Drift) first. Writes queue locally and sync on reconnect. A connectivity banner shows offline status. Users can read cached Shorts, take quizzes, and save bookmarks without internet. Cross-device sync uses last-write-wins for settings, merge for interactions, server-authoritative for content.

### 4.7 Haptic Feedback & Gestures

Swipe left/right for next/previous Short, swipe up to dive deeper, swipe down to go up a level, long press to bookmark, double tap to mark done. Each gesture paired with haptic feedback and visual confirmation.

### 4.8 Location-Based Content Prioritization

Geeky uses coarse location (city/state level) to prioritize geographically-relevant content from the user's knowledge base. If a user lives in Arizona, news articles, local research, and region-specific content about Arizona are surfaced before similar content from different areas based on the uploaded sources. This happens entirely through semantic tagging and location-aware scoring. No content is filtered out, just reordered for relevance.

**Implementation:** When processing ingested content, the pipeline extracts location entities (cities, states, regions) via NER. The adaptive recommendation engine compares these against the user's coarse location (obtained with consent via `ACCESS_COARSE_LOCATION`, stored as city/state labels). Scoring applies a modest geographic relevance boost (~10-15% weight) to local content while preserving diversity.

**Privacy-First Design:** Location is coarse-only for now and not precise coordinates, processed client-side, never shared with third parties. Users can set a manual "Home Region" without granting location permission. Location labels (not coordinates) are stored locally in Drift and optionally synced as simple text labels ("Arizona, US") to Firestore for cross-device consistency. Can provide a Settings toggle: "Prioritize content from my region." Users can review and edit detected locations on any Short. Transparent UI shows "Showing more Arizona content" with option to disable per-session.

### 4.9 Device Context & In-App Purchases

Time-of-day, session duration, device type, and geographic location feed into recommendation scoring as contextual features. RevenueCat handles subscriptions (Free / Premium $4.99/mo / $39.99/yr) across App Store and Play Store with receipt validation and Firestore sync.

### 4.10 Integration Summary Table

| Capability | Package / API | What It Enables |
|-----------|--------------|----------------|
| OS Share Sheet | `receive_sharing_intent` | Ingest from any app (YouTube, LinkedIn, Chrome, etc.) |
| External Sharing | `share_plus` | Share Shorts to social media, messaging, email |
| Push Notifications | Firebase Cloud Messaging | Review reminders, streak alerts, new content, deep links |
| Text-to-Speech | `flutter_tts` | Audio playback of Shorts, accessibility support |
| Camera / Microphone | `file_picker` | Whiteboard OCR, voice memos, document scanning |
| File Access | `file_picker` | Upload PDFs/DOCX, export JSON/CSV, manage cache |
| Deep Linking | GoRouter + App Links | Direct navigation from notifications, shared links |
| Offline Storage | Drift (SQLite) | Read cached Shorts, queue interactions, sync on reconnect |
| Connectivity | `connectivity_plus` | Offline/online detection, degraded mode, sync triggers |
| Location Services | `geolocator` | Geographic content prioritization, local relevance boosting |
| Haptic Feedback | `HapticFeedback` | Tactile confirmation for swipe gestures and actions |
| Responsive Layout | `MediaQuery` | Adapt UI for phone, tablet, and web form factors |
| Subscriptions | RevenueCat | Free/premium tiers, App Store + Play Store billing |

---

## 5. Visualizations & Diagrams

### 5.1 High-Level System Architecture

```
+-----------------+        +------------------+
|  Flutter App    | <----> |  Firebase Suite   |
|  Riverpod 3.0   |  sync  |  Auth, Firestore |
|  GoRouter       |        |  Storage, FCM    |
|  Drift (SQLite) |        |  Cloud Functions |
+-------+---------+        +--------+---------+
        | REST (Dio)                 | Triggers
        v                           v
+-------+---------+        +--------+---------+
| FastAPI Backend |        | Cloud Functions  |
| (Cloud Run)     |        | on_note_created  |
| Pipeline, RAG,  |        | on_interaction   |
| KG, Recommend   |        | on_source_poll   |
+--+-----------+--+        +------------------+
   |           |
   v           v
+------+  +--------+
|Chroma|  | Gemini |
| DB   |  |  API   |
+------+  +--------+
```

### 5.2 Content Processing Pipeline

```
User Action (Share / Upload / Paste / Camera / Voice)
        |
        v
  Note Created in Firestore --> Cloud Function Trigger
        |
        v
  EXTRACT: TEXT|IMAGE(Vision OCR)|AUDIO(STT)|LINK(BS4)|VIDEO|FILE
        |
        v
  CHUNK: Structural --> Paragraph --> Semantic --> Sentence (~1000w)
        |
        v
  DEDUP: Exact Hash --> MinHash/LSH --> Semantic(>=0.85) --> Cross-Modal
        |  (novel chunks only)
        v
  EMBED: Gemini embedding-001 (768 dims) --> ChromaDB (user-scoped)
        |
        v
  GENERATE: Summarize --> Tag Topics --> Score Difficulty --> Prompts
        |
        v
  UPDATE: Knowledge Graph nodes/edges --> Roadmap recalculation
```

### 5.3 Knowledge Graph Structure

```
  LEVEL 1 (Broad):     [AI]              [Biology]
                       / | \                 |
  LEVEL 2 (Detail): [ML] [NLP] [CV]     [Neuroscience]
                     / \    |
  LEVEL 3+ (Deep): [Backprop] [Transformer] [Object Detection]

  Edge Types:  ====> prerequisite (DAG)    ----> related (cyclic OK)
               ....> deeper/broader        ~~~> dynamic (k-NN, auto)
  Node Colors: GREEN=mastered  YELLOW=in-progress  GREY=unread  RED=locked
```

### 5.4 Adaptive Learning Engine

```
+------------------------------------------------------------+
|  User Interaction (read/skip/save/quiz/navigate/feedback)  |
+---------------------------+--------------------------------+
                            |
                            v
+---------------------------+--------------------------------+
|  User Profile: interests, familiarity, BKT params,         |
|  learning mode, strengths/weaknesses, session patterns,    |
|  geographic location (coarse: city/state)                  |
+---------------------------+--------------------------------+
                            |
                            v
+---------------------------+--------------------------------+
|  SCORING: 0.40*relevance + 0.30*capability + 0.30*novelty |
|  + difficulty calibration (BKT)                            |
|  + diversity constraint (topic variety)                    |
|  + context adjustment (time, device, session, location)    |
|  + geographic relevance boost (~10-15% for local content)  |
|  + exploration bonus (contextual bandit)                   |
+---------------------------+--------------------------------+
                            |
                            v
+---------------------------+--------------------------------+
|  ROADMAP: score unread --> respect prereq DAG -->           |
|  familiarity filter --> ordered recommendation list         |
+------------------------------------------------------------+
```

### 5.5 RAG Query Pipeline

```
Question --> Query Expansion (synonyms from user's KB)
    --> Hybrid Retrieval (ChromaDB dense + BM25 sparse, user-scoped)
    --> Cross-Encoder Reranking (top 20)
    --> MMR Diversification (lambda=0.7, top 10)
    --> Context Compression (quality filter -> dedup -> relevance -> budget)
    --> LLM Generation (Gemini + grounded citations)
    --> Answer with source Short links
```

### 5.6 User Journey & Screen Map

```
Splash --> Auth (Email/Google/Guest) --> Onboarding (Interests/Sources/Goals)
    |
    v
Home (Bottom Nav Tabs):
  Feed -----> Short View (read/done/skip/deeper/up/related/quiz/TTS/share)
  Explore --> KG Visualization | Search | Topics
  Library --> Notes | Modules | Bookmarks | Sources | Store
  Profile --> Stats | Streaks | Achievements | Settings | Export
  Chat -----> RAG Q&A with citations and follow-ups
```

### 5.7 Offline-First Data Flow

```
+-------------------------------+
|        FLUTTER APP            |
|                               |
|   Provider calls getData()    |
|            |                  |
|            v                  |
|   +------------------+        |
|   | Check Drift      |        |
|   | (local SQLite)   |        |
|   +--------+---------+        |
|            |                  |
|     +------+------+          |
|     |             |           |
|  Cached?       Not cached     |
|     |             |           |
|     v             v           |
|  Return        Online?        |
|  immediately    |    |        |
|     +       Yes   No         |
|     |        |      |        |
|     |        v      v        |
|     |   Firestore  Return    |
|     |   fetch +    stale +   |
|     |   update     "offline" |
|     |   Drift      badge     |
|     +--------+               |
|                               |
|   WRITES: Always to Drift     |
|   first. If online, also to   |
|   Firestore. If offline,      |
|   queued (synced=false) and   |
|   flushed on reconnect.       |
+-------------------------------+
```

### 5.8 Phone Integration Map

```
INBOUND:                          OUTBOUND:
  YouTube/LinkedIn/Twitter/       Share Short --> share_plus --> Any App
    Chrome --> OS Share Sheet      TTS Playback --> flutter_tts --> Speaker
    --> receive_sharing_intent    Notifications --> FCM --> System Tray
  Camera/Mic --> file_picker      Deep Links --> App Links --> Screen
  Files --> file_picker           Export --> file_picker --> Storage

DEVICE CONTEXT:
  Network --> connectivity_plus --> Offline/Online mode
  Location --> geolocator (coarse) --> Geographic content prioritization
  Time --> DateTime --> Context-aware recommendations
  Device --> MediaQuery --> Responsive layout
  Billing --> RevenueCat --> Subscription management
```

---

## 6. Deliverables & Milestones

### Phase 0 — Foundation
**Goal:** Project skeleton, CI/CD, dev environment.

| Deliverable | Details |
|------------|---------|
| Flutter scaffold | Feature-first folder structure, Riverpod 3.0 with codegen, GoRouter skeleton |
| Local DB | Drift schema: CachedShorts, PendingInteractions, CachedModules, UserPreferences |
| Firebase | Auth + Firestore + Storage + FCM configured, security rules deployed |
| Backend | FastAPI on Cloud Run with `/health` endpoint, ChromaDB on separate Cloud Run instance |
| CI/CD | GitHub Actions: Flutter (analyze, test, build) + Backend (pytest, docker, deploy) |
| Theme | flex_color_scheme with light/dark/system. Base widgets: loading, error, empty, shimmer |

**Exit:** `flutter run` shows splash. Backend returns 200. CI green.

### Phase 1 — Core Learning Loop
**Goal:** Users sign up, add notes, see Shorts, interact with them.

| Deliverable | Details |
|------------|---------|
| Authentication | Email/password, Google Sign-In, guest mode, session persistence |
| Onboarding | Feature tour, interest selection, source setup, goals, proficiency self-assessment |
| Note ingestion | Text entry, URL fetch, file upload, share intent receiver (receive_sharing_intent) |
| Processing pipeline | Extraction (all media types), chunking, hash + semantic dedup, embedding, Short generation, location entity extraction |
| Shorts feed | Card-based swipe UI, done/skip/save, markdown rendering, time tracking |
| Recommendations | Basic multi-factor scoring, next-Short suggestion |
| Location | Coarse location permission, manual region setup, geographic content tagging |
| Offline | Drift cache for Shorts, connectivity banner, write queue with sync |

**Exit:** User shares a URL from Chrome, sees a generated Short, marks it done, gets next rec. Works offline.

### Phase 2 — Intelligence Layer
**Goal:** Knowledge Graph, adaptive learning, RAG bring the platform to life.

| Deliverable | Details |
|------------|---------|
| Knowledge Graph | Concepts + relationships in Firestore, NER during pipeline, 3-level hierarchy |
| KG navigation | Dive deeper, go up, related, next. Universal traversal guarantee |
| KG visualization | Interactive graph with graphview, user progress overlay, pan/zoom/filter |
| Adaptive engine | Multi-factor scoring, BKT per concept, familiarity adaptation, difficulty calibration, geographic relevance |
| Location services | Coarse location (opt-in), geographic entity extraction (NER), location-aware content scoring |
| RAG | Natural language Q&A, hybrid retrieval (dense + sparse), grounded citations |
| Modules | Auto-generated from clustering + manual creation, progress tracking, auto-update |

**Exit:** User visualizes KG, gets adaptive recs, asks their knowledge base questions, studies through modules.

### Phase 3 — Engagement & Retention
**Goal:** Spaced repetition, quizzes, analytics, and notifications complete the learning loop.

| Deliverable | Details |
|------------|---------|
| FSRS engine | 0.9 target retention, optimal review interval scheduling |
| Quizzes | MCQ, T/F, fill-blank, open-ended (AI-graded), adaptive difficulty |
| Notifications | FCM: review reminders, streak alerts, new content, deep links. Configurable prefs |
| Analytics | Streaks, completion stats, per-topic charts (fl_chart), dashboard, velocity, badges |
| Sources | RSS management, health monitoring, polling, validation |
| Social | Share Shorts via share_plus, deep links for shared content |

**Exit:** User gets review reminders, takes adaptive quizzes, tracks streaks and mastery, manages sources.

### Phase 4 — Polish & Launch
**Goal:** Premium features, production hardening, store, accessibility.

| Deliverable | Details |
|------------|---------|
| Subscriptions | RevenueCat free/premium, PremiumGate widget, backend middleware, 7-day trial |
| Module Store | Browse, preview, download pre-made modules |
| Advanced RAG | Cross-encoder reranking, MMR, compression, query expansion, mind maps, audio overviews |
| Advanced pipeline | MinHash dedup, cross-modal dedup, Bloom filters, concept discovery, conflict detection |
| Production | Rate limiting, sanitization, CORS, logging, GDPR (export, erasure, consent) |
| Accessibility | Screen reader labels, high-contrast themes, keyboard nav, TTS, responsive layout |

**Exit:** App Store / Play Store ready. Subscriptions work end-to-end. GDPR compliant.

### Phase 5 — Post-Launch
**Goal:** Advanced ML, browser extension, content expansion.

| Deliverable | Details |
|------------|---------|
| Advanced ML | RL path optimization, GNN policy training, contextual bandits, per-user FSRS tuning |
| Browser extension | Chrome/Firefox/Safari/Edge: page save, highlights, auto-highlighting, sync |
| Content expansion | Newsletter ingestion, social feed subscriptions, predefined source catalogs |
| Platform growth | Feature flags, A/B testing for recommendations, performance monitoring |

### Milestone Summary

| Phase | Name | Key Outcome |
|-------|------|-------------|
| 0 | Foundation | Project skeleton, infra, CI/CD |
| 1 | Core Loop | Notes in, Shorts out, basic recs |
| 2 | Intelligence | KG, adaptive engine, RAG, modules |
| 3 | Retention | FSRS, quizzes, notifications, analytics |
| 4 | Launch | Subscriptions, store, production-ready |
| 5 | Expansion | RL recs, browser extension, social |

---

## 7. Risks & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Gemini API rate limits | High | Pipeline stalls | Exponential backoff, task queue, batch processing, embedding cache |
| ChromaDB unavailability | Medium | Degraded search | Fallback to keyword-only search, Cloud Run health checks + auto-restart |
| Hallucinated summaries | Medium | User trust erosion | Retrieval grounding, short outputs, consistency checks, user feedback loop |
| Free tier cost overruns | Medium | Service interruption | Per-user limits enforced in backend, scale-to-zero, billing threshold alerts |
| Cold start (new users) | High | Poor first impression | Onboarding data seeds recs, pre-made store modules, content-based filtering |
| Data inconsistency | Medium | Orphaned content | Lifecycle manager with cascading ops, dedup audit logs, periodic consistency checks |
| Offline sync conflicts | Low | Minor data loss | Last-write-wins for settings, merge for interactions, server-authoritative for content |

### Cost Profile

Geeky is designed to operate within Google Cloud's free tier during early growth:

| Service | Free Tier | Estimated MVP Usage |
|---------|----------|-------------------|
| Firestore | 50K reads, 20K writes/day | Well within for ~100 users |
| Cloud Run | 2M requests, 180K vCPU-sec/mo | Scale-to-zero minimizes cost |
| Cloud Storage | 5GB | Media files + ChromaDB persistence |
| Cloud Functions | 2M invocations/month | Event triggers per note lifecycle |
| Gemini API | 15 RPM, 1M tokens/day | Summarization + embeddings + NER |
| Firebase Auth | 10K verifications/month | Sufficient for early growth |
| FCM | Unlimited | Push notifications |

Scale-to-zero means zero cost when idle. Premium revenue ($4.99/mo per user) covers marginal API usage at scale.

---

## 8. Conclusion

Geeky occupies a gap between personal knowledge management and adaptive learning — a space where no existing product delivers the full picture. The research validates that every underlying technology is production-proven: transformer summarization, vector search, knowledge graphs, Bayesian knowledge tracing, and FSRS spaced repetition. What has been missing is a consumer product that weaves them together into a phone-native experience.

The phased delivery plan ensures each milestone ships a usable increment. Phase 1 alone gives users a working app — share content, see Shorts, get recommendations. Each subsequent phase adds intelligence, engagement, and polish. The deep phone integration (share intents, notifications, TTS, gestures, offline-first, billing) makes this feel like a native mobile experience, not a web wrapper.

The cost model starts at zero (Google Cloud free tier) and scales with users through premium subscriptions. The architecture is designed for a solo developer to build and maintain, with clear separation of concerns and no unnecessary infrastructure.

---

## 9. References

- **Adaptive Learning:** ALEKS (Knowledge Space Theory), Khan Academy (DAG + MAP Growth), Coursera (meta-path GCNs), BKT (hidden Markov model for mastery)
- **Knowledge Graphs:** Microsoft GraphRAG, Graphiti/Zep AI, Neo4j LLM KG Builder, Stream2Graph
- **NLP:** NVIDIA chunking strategies, FactPEGASUS, SemDeDup (cluster-and-prune dedup)
- **Spaced Repetition:** FSRS (21 params, 20-30% fewer reviews than SM-2)
- **Recommendation:** Netflix hybrid architecture, PDR (7.41% improvement), PENETRATE, Vassoyan et al. (graph RL)
- **RAG:** BGE-Reranker, MMR, BM25 hybrid retrieval
- **Internal Docs:** [REQUIREMENTS.md](REQUIREMENTS.md), [RESEARCH.md](RESEARCH.md), [RESEARCH_ANALYSIS.md](RESEARCH_ANALYSIS.md), [ARCHITECTURE.md](ARCHITECTURE.md)