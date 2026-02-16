# Geeky — Project Rules & Context

## Project Overview
Geeky ("Notes Recall") is an AI-driven adaptive educational platform. Flutter frontend (complete) + Python backend (in progress). Transforms multimedia notes into bite-sized Shorts, organized via Knowledge Graph, with adaptive learning paths.

## Architecture
- **Frontend**: Flutter + Riverpod 3.0 + Drift (SQLite) + GoRouter
- **Backend**: FastAPI + Celery + ChromaDB + Firebase Admin SDK
- **AI**: Gemini 2.5 Flash (generation), gemini-embedding-001 (embeddings), LlamaIndex (RAG)
- **Infra**: Google Cloud Run (scale-to-zero), Redis Cloud, Firestore

## Backend Code Rules

### 1. Protocol-First Design (CRITICAL)
Every external dependency MUST be behind a Python Protocol (typing.Protocol). This is the #1 architectural rule.

```python
# CORRECT — Protocol interface in base.py, implementation separate
class EmbeddingProvider(Protocol):
    async def embed(self, texts: list[str]) -> list[list[float]]: ...

class GeminiEmbedder:  # implements EmbeddingProvider implicitly
    async def embed(self, texts: list[str]) -> list[list[float]]: ...

# WRONG — Direct dependency on concrete class
class ChunkService:
    def __init__(self):
        self.embedder = GeminiEmbedder()  # NO! Use DI
```

**Protocols exist for**: EmbeddingProvider, LLMProvider, VectorStore, DocumentParser, NERExtractor, EdgeClassifier, Reranker, SparseSearchEngine, NotificationSender, SpacedRepetitionScheduler, Repository (base).

### 2. Layered Architecture
```
API routes (thin) → Services (business logic) → Repositories (data access)
                                               → Integrations (external APIs)
```
- **Routes**: Only validation, auth, and delegation. No business logic.
- **Services**: All business logic. Receive dependencies via constructor injection.
- **Repositories**: Firestore CRUD only. No business logic. Behind Protocol.
- **Integrations**: External API wrappers (Gemini, ChromaDB). Behind Protocol.

### 3. Dependency Injection
Use FastAPI's `Depends()` for wiring. All services receive their dependencies via constructor, never import globals.

```python
# In dependencies.py — single source of truth for wiring
def get_embedding_provider() -> EmbeddingProvider:
    return GeminiEmbedder(settings.gemini_api_key)

def get_chunk_service(
    embedder: EmbeddingProvider = Depends(get_embedding_provider),
) -> ChunkService:
    return ChunkService(embedder=embedder)
```

### 4. Pydantic Models
- All request/response schemas use Pydantic v2 BaseModel
- Internal domain objects also use Pydantic for validation
- Firestore documents <-> Pydantic models via `model_dump()` / `model_validate()`
- Use `from __future__ import annotations` in all model files

### 5. Async First
- All I/O operations MUST be async (database, API calls, file I/O)
- Use `asyncio` throughout, never blocking calls in async context
- Celery tasks are the exception (they run in worker processes, can be sync)

### 6. Error Handling
- Services raise domain exceptions (e.g., `NoteNotFoundError`, `ProcessingError`)
- API layer catches and maps to HTTP responses via exception handlers
- Never return raw exception traces to clients
- All errors include correlation_id for tracing

### 7. User Data Isolation (CRITICAL)
- Every Firestore query MUST include user_id filter
- Every ChromaDB query MUST include `where={"user_id": user_id}`
- Repository methods always require user_id as first parameter
- Never trust client-provided user_id — always use auth token's uid

### 8. Configuration
- All config via pydantic-settings (reads from env vars / .env)
- No hardcoded values for URLs, keys, thresholds, or magic numbers
- Feature flags in Firestore `app_config/global` document

### 9. Testing Patterns
- Unit tests: mock all external dependencies via Protocol implementations
- Integration tests: use TestClient + mock Firebase/ChromaDB
- Test files mirror source structure: `tests/unit/services/test_chunker.py`
- Fixtures in `conftest.py`, shared across test modules

### 10. Naming Conventions
- Files: `snake_case.py`
- Classes: `PascalCase`
- Functions/methods: `snake_case`
- Constants: `UPPER_SNAKE_CASE`
- Protocols: `{Noun}Provider`, `{Noun}Store`, `{Noun}Extractor` etc.
- Concrete implementations: `{Vendor}{Noun}` (e.g., `GeminiEmbedder`, `SpacyNERExtractor`)
- Repositories: `{Entity}Repository`
- Services: `{Feature}Service`

### 11. File Organization
- One class per file (except small related classes)
- Protocols in `base.py` within their service directory
- Factories in `factory.py` within their service directory
- All `__init__.py` files export the public API of their package

### 12. Celery Tasks
- Tasks are thin wrappers that call service methods
- Tasks must be idempotent (safe to retry)
- Use `task.retry()` with exponential backoff for transient failures
- Log task start/end with correlation_id

### 13. API Versioning
- All endpoints under `/api/v1/`
- Response envelope: `{ "data": ..., "meta": { "page", "total" } }` for lists
- Error envelope: `{ "error": { "code", "message", "detail" } }`
- Pagination: cursor-based preferred, offset-based acceptable

### 14. Git & Commits
- Backend changes: prefix commit with `backend:` or `be:`
- Flutter changes: prefix with `frontend:` or `fe:`
- Infra changes: prefix with `infra:`
- Keep commits atomic — one logical change per commit

## Frontend Code Rules
- Riverpod 3.x: `ThemeModeNotifier` generates `themeModeProvider` (drops "Notifier" suffix)
- Provider files: `import 'package:riverpod_annotation/riverpod_annotation.dart'`
- Widget files: `import 'package:flutter_riverpod/flutter_riverpod.dart'`
- `Ref` (not specific ref types) for functional providers
- `AsyncValue.value` returns `T?` — use instead of removed `.valueOrNull`
- Drift for local DB (not Hive/Isar — abandoned)
- GoRouter for navigation with auth guards
- DTO pattern: `abstract final class XDto` with static `fromRow()` / `toCompanion()`

## Key Documentation
- `docs/REQUIREMENTS.md` — 321+ requirements, source of truth
- `docs/ARCHITECTURE.md` — Exhaustive architecture reference
- `docs/RESEARCH.md` — Academic research backing design decisions
- `docs/DESIGN_DECISIONS.md` — Tradeoff analyses with decision matrices
- `docs/PIPELINE_COMPARISON.md` — Content pipeline architecture comparison
- `backend/plan.md` — Backend implementation plan and progress
