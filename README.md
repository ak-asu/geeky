# Geeky

Geeky is an offline-first adaptive educational platform that turns scattered multimedia notes into bite-sized learning Shorts, organizes them in a Knowledge Graph, and continuously personalizes what to learn next.

This repository contains:
- Flutter application (primary product surface)
- Python FastAPI backend (in progress)
- Documentation, research, and static landing page

## Why Geeky

Geeky targets five common self-learning failures:
- Content scatter across apps and formats
- Information overload and duplication
- Passive consumption without active recall
- No adaptive sequence for what to study next
- Retention decay without spaced repetition

## Core Product Capabilities

- Multimedia ingestion from text, links, files, and sharing workflows
- AI-generated Shorts with topic tagging and difficulty metadata
- Knowledge Graph navigation (deeper, broader, related, next)
- Adaptive recommendations using relevance, capability, and novelty signals
- Spaced repetition and quiz-based reinforcement
- RAG-powered Q&A over user content (premium)
- Offline-first reads/writes with reconnect sync behavior

## Free vs Premium

- Free tier:
	- Note ingestion and note feed access
	- Basic search and basic analytics
	- Source limit: 3
	- Store module download limit: 3
- Premium tier:
	- Shorts generation and Shorts feed
	- Knowledge Graph and RAG query
	- Quiz + spaced repetition system
	- Full analytics and advanced learning features

## Architecture Overview

- Frontend:
	- Flutter 3.x
	- Riverpod 3 with code generation
	- Drift (SQLite) for local persistence
	- GoRouter for guarded navigation
- Backend:
	- FastAPI + Pydantic
	- Protocol-first dependency boundaries
	- AI and retrieval pipeline services
- Infrastructure:
	- Firebase Auth, Firestore, Cloud Storage, FCM
	- Cloud Run for backend services
	- Gemini API for generation/embeddings
	- ChromaDB for vector search

## Repository Layout

```text
lib/                Flutter app source
landing-page/       Static marketing page
backend/            FastAPI backend services and workers
docs/               Architecture, research, requirements, and decisions
assets/             App assets and mock content fixtures
test/               Flutter tests
```

## Flutter Setup

Prerequisites:
- Flutter SDK (stable channel)
- Dart SDK (bundled with Flutter)
- Android Studio or VS Code with Flutter tooling

Install dependencies:

```bash
flutter pub get
```

Generate code (Riverpod, Freezed, Drift, JSON):

```bash
dart run build_runner build --delete-conflicting-outputs
```

Run app:

```bash
flutter run
```

Run Flutter tests:

```bash
flutter test
```

## Backend Setup (Current Scaffold)

The backend is under active development. Start with:

```bash
cd backend
./scripts/local_setup.sh
cp .env.example .env
docker-compose up
```

Open API docs at `http://localhost:8000/docs`.

Run backend tests:

```bash
cd backend
pytest tests/ -v
```

## Landing Page

The static landing page lives in `landing-page/`.

To preview locally:

```bash
cd landing-page
python3 -m http.server 8080
```

Then open `http://localhost:8080`.

## Project Status

- Flutter frontend: substantial feature coverage and local-first architecture
- Backend: foundational structure, protocol boundaries, and service skeletons in place
- AI/ML pipeline and production hardening: ongoing

## Key Documentation

- `docs/REQUIREMENTS.md` - product and engineering requirements
- `docs/ARCHITECTURE.md` - full system architecture
- `docs/RESEARCH.md` - research foundation
- `docs/DESIGN_DECISIONS.md` - tradeoff and decision logs
- `backend/plan.md` - backend implementation plan

## License

No license file is currently declared in this repository.