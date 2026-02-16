# Geeky Backend — Implementation Plan & Progress

## Phases

### Phase 1: Foundation & Infrastructure [IN PROGRESS]
- [x] CLAUDE.md + backend/plan.md
- [ ] Directory structure + __init__.py files
- [ ] All Protocol definitions (base.py files)
- [ ] Config (pydantic-settings), exceptions, main.py
- [ ] Auth middleware (Firebase token verification)
- [ ] Rate limit middleware, error handler, logging
- [ ] Base repository (FirestoreBaseRepository)
- [ ] Dependencies.py (DI wiring)
- [ ] Celery app configuration
- [ ] Docker (Dockerfile, Dockerfile.worker, docker-compose.yml)
- [ ] Requirements, pyproject.toml, .env.example
- [ ] GitHub Actions workflow
- [ ] Deployment scripts
- [ ] Health check + /me endpoints
- [ ] Test fixtures + mock Protocols
- [ ] README.md

### Phase 2: Notes CRUD + Content Processing Pipeline [ ]
- [ ] Concrete implementations: DoclingParser, GeminiEmbedder, GeminiLLM, ChromaDBStore
- [ ] Notes, Chunks, Shorts, ProcessingTask repositories
- [ ] Hierarchical chunker (CP-03)
- [ ] 4-stage deduplicator (CP-05)
- [ ] Short generator (CP-07)
- [ ] Pipeline orchestrator (Celery task chain)
- [ ] Notes CRUD API endpoints
- [ ] Shorts listing API endpoints
- [ ] Unit + integration tests

### Phase 3: Knowledge Graph + NER [ ]
- [ ] SpacyNERExtractor, SpacyEdgeClassifier
- [ ] Concept + Relationship repositories
- [ ] DAG validator, community detector, path finder
- [ ] KG navigator, temporal tracker
- [ ] Pipeline extension (NER -> KG update)
- [ ] KG API endpoints
- [ ] Tests

### Phase 4: RAG Pipeline + Search [ ]
- [ ] CrossEncoderReranker, BM25SEngine
- [ ] Hybrid retriever, MMR diversifier
- [ ] Context compressor, query expander
- [ ] RAG orchestrator (LlamaIndex)
- [ ] RAG + search API endpoints
- [ ] Tests

### Phase 5: Quiz, FSRS, Recommendation & User Profiling [ ]
- [ ] Quiz generator, AI grader
- [ ] FSRS scheduler (py-fsrs)
- [ ] Multi-factor scorer (40/30/30), BKT tracker
- [ ] User profiler, feed ranker
- [ ] Interaction sync processor
- [ ] Quiz, recommendation, user, sync API endpoints
- [ ] Tests

### Phase 6: Analytics, Bookmarks, Sources, Modules, Notifications, Lifecycle [ ]
- [ ] Analytics dashboard, streak tracker, achievement engine
- [ ] Bookmarks, sources, modules CRUD
- [ ] FCM notifications
- [ ] Lifecycle cascades, orphan cleanup
- [ ] GDPR export/delete
- [ ] Celery beat scheduled tasks
- [ ] All remaining API endpoints
- [ ] Tests

### Phase 7: Deployment & Flutter Integration [ ]
- [ ] GCP setup scripts
- [ ] Cloud Run deployment
- [ ] Firebase Auth on Flutter
- [ ] Dio client with auth interceptor
- [ ] Repository remote data sources
- [ ] Offline sync integration

### Phase 8: Hardening & Production Readiness [ ]
- [ ] Performance verification (all targets)
- [ ] Security audit
- [ ] Input sanitization
- [ ] Graceful degradation
- [ ] Feature flags
- [ ] Load testing

## Tech Stack
| Component | Choice | Swappable Via |
|-----------|--------|---------------|
| Framework | FastAPI + Pydantic v2 | -- |
| Vector DB | ChromaDB | `VectorStore` Protocol |
| Task Queue | Celery + Redis Cloud | -- |
| AI Generation | Gemini 2.5 Flash | `LLMProvider` Protocol |
| Embeddings | gemini-embedding-001 | `EmbeddingProvider` Protocol |
| RAG | LlamaIndex | `RAGOrchestrator` service |
| NER | spaCy | `NERExtractor` Protocol |
| KG Algorithms | NetworkX | Direct |
| Reranking | MiniLM-L6-v2 | `Reranker` Protocol |
| BM25 | BM25S | `SparseSearchEngine` Protocol |
| Doc Parsing | Docling | `DocumentParser` Protocol |
| FSRS | py-fsrs | `SpacedRepetitionScheduler` Protocol |
| Notifications | FCM | `NotificationSender` Protocol |
