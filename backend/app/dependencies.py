"""Dependency injection wiring — single source of truth.

ALL Protocol-to-implementation bindings live here. To swap a technology,
change ONE function in this file.

Usage in routes:
    @router.get("/")
    async def list_notes(
        user_id: CurrentUserId,
        note_repo: NoteRepository = Depends(get_note_repository),
    ):
        ...
"""

from __future__ import annotations

from functools import lru_cache
from typing import Any

from app.config import Settings, get_settings


# ============================================================
# Firebase / Firestore
# ============================================================


@lru_cache
def get_firestore_db() -> Any:
    """Get the Firestore client. Swap this to change database backend."""
    from app.integrations.firebase_client import get_firestore_client  # noqa: PLC0415

    return get_firestore_client()


# ============================================================
# LLM Provider
# ============================================================


@lru_cache
def get_llm_provider():
    """Get the LLM provider. Currently: Gemini 2.5 Flash."""
    from app.services.llm.gemini_llm import GeminiLLM  # noqa: PLC0415

    settings = get_settings()
    return GeminiLLM(api_key=settings.gemini_api_key, model=settings.gemini_model)


# ============================================================
# Embedding Provider
# ============================================================


@lru_cache
def get_embedding_provider():
    """Get the embedding provider. Currently: Gemini embedding-001."""
    from app.services.pipeline.embedder.gemini_embedder import GeminiEmbedder  # noqa: PLC0415

    settings = get_settings()
    return GeminiEmbedder(
        api_key=settings.gemini_api_key,
        model=settings.gemini_embedding_model,
        dimensions=settings.gemini_embedding_dimensions,
    )


# ============================================================
# Vector Store
# ============================================================


@lru_cache
def get_vector_store():
    """Get the vector store. Currently: ChromaDB."""
    from app.services.vector_store.chromadb_store import ChromaDBStore  # noqa: PLC0415

    settings = get_settings()
    return ChromaDBStore(
        host=settings.chromadb_host,
        port=settings.chromadb_port,
        collection_name=settings.chromadb_collection_name,
    )


# ============================================================
# Document Parser
# ============================================================


@lru_cache
def get_document_parser():
    """Get the document parser. Currently: Docling + Gemini Vision fallback."""
    from app.services.pipeline.extractor.docling_parser import DoclingParser  # noqa: PLC0415

    return DoclingParser()


# ============================================================
# NER Extractor
# ============================================================


@lru_cache
def get_ner_extractor():
    """Get the NER extractor. Currently: spaCy."""
    from app.services.ner.spacy_extractor import SpacyNERExtractor  # noqa: PLC0415

    return SpacyNERExtractor()


# ============================================================
# Edge Classifier
# ============================================================


@lru_cache
def get_edge_classifier():
    """Get the edge classifier. Currently: spaCy dependency parsing."""
    from app.services.ner.spacy_extractor import SpacyEdgeClassifier  # noqa: PLC0415

    return SpacyEdgeClassifier()


# ============================================================
# Reranker
# ============================================================


@lru_cache
def get_reranker():
    """Get the reranker. Currently: ms-marco-MiniLM-L6-v2."""
    from app.services.rag.reranker.cross_encoder import CrossEncoderReranker  # noqa: PLC0415

    return CrossEncoderReranker()


# ============================================================
# Sparse Search Engine
# ============================================================


@lru_cache
def get_sparse_search_engine():
    """Get the sparse search engine. Currently: BM25S."""
    from app.services.search.bm25s_engine import BM25SSearchEngine  # noqa: PLC0415

    return BM25SSearchEngine()


# ============================================================
# Spaced Repetition Scheduler
# ============================================================


@lru_cache
def get_spaced_repetition_scheduler():
    """Get the spaced repetition scheduler. Currently: py-fsrs."""
    from app.services.quiz.scheduler.fsrs_scheduler import FSRSScheduler  # noqa: PLC0415

    settings = get_settings()
    return FSRSScheduler(desired_retention=settings.fsrs_desired_retention)


# ============================================================
# Notification Sender
# ============================================================


@lru_cache
def get_notification_sender():
    """Get the notification sender. Currently: Firebase Cloud Messaging."""
    from app.services.notification.fcm_sender import FCMNotificationSender  # noqa: PLC0415

    return FCMNotificationSender()


# ============================================================
# Repositories
# ============================================================


def get_note_repository():
    """Get the note repository."""
    from app.models.note import NoteDocument  # noqa: PLC0415
    from app.repositories.note_repo import NoteRepository  # noqa: PLC0415

    return NoteRepository(db=get_firestore_db())


def get_short_repository():
    """Get the short repository."""
    from app.repositories.short_repo import ShortRepository  # noqa: PLC0415

    return ShortRepository(db=get_firestore_db())


def get_chunk_repository():
    """Get the chunk repository."""
    from app.repositories.chunk_repo import ChunkRepository  # noqa: PLC0415

    return ChunkRepository(db=get_firestore_db())


def get_module_repository():
    """Get the module repository."""
    from app.repositories.module_repo import ModuleRepository  # noqa: PLC0415

    return ModuleRepository(db=get_firestore_db())


def get_concept_repository():
    """Get the concept repository."""
    from app.repositories.concept_repo import ConceptRepository  # noqa: PLC0415

    return ConceptRepository(db=get_firestore_db())


def get_relationship_repository():
    """Get the relationship repository."""
    from app.repositories.relationship_repo import RelationshipRepository  # noqa: PLC0415

    return RelationshipRepository(db=get_firestore_db())


def get_user_repository():
    """Get the user repository."""
    from app.repositories.user_repo import UserRepository  # noqa: PLC0415

    return UserRepository(db=get_firestore_db())


def get_interaction_repository():
    """Get the interaction repository."""
    from app.repositories.interaction_repo import InteractionRepository  # noqa: PLC0415

    return InteractionRepository(db=get_firestore_db())


def get_quiz_repository():
    """Get the quiz repository."""
    from app.repositories.quiz_repo import QuizRepository  # noqa: PLC0415

    return QuizRepository(db=get_firestore_db())


def get_bookmark_repository():
    """Get the bookmark repository."""
    from app.repositories.bookmark_repo import BookmarkRepository  # noqa: PLC0415

    return BookmarkRepository(db=get_firestore_db())


def get_source_repository():
    """Get the source repository."""
    from app.repositories.source_repo import SourceRepository  # noqa: PLC0415

    return SourceRepository(db=get_firestore_db())


def get_notification_repository():
    """Get the notification repository."""
    from app.repositories.notification_repo import NotificationRepository  # noqa: PLC0415

    return NotificationRepository(db=get_firestore_db())


def get_processing_task_repository():
    """Get the processing task repository."""
    from app.repositories.processing_task_repo import ProcessingTaskRepository  # noqa: PLC0415

    return ProcessingTaskRepository(db=get_firestore_db())


def get_analytics_repository():
    """Get the analytics repository."""
    from app.repositories.analytics_repo import AnalyticsRepository  # noqa: PLC0415

    return AnalyticsRepository(db=get_firestore_db())
