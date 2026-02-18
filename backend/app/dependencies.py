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
# Feature Flags
# ============================================================


@lru_cache
def get_feature_flags():
    """Get the feature flag provider (singleton). Firestore-backed with 5-min TTL.

    Cached with @lru_cache so the same FirestoreFeatureFlags instance is reused
    across all requests — allowing the in-process TTL cache to function correctly.
    """
    from app.services.feature_flags.firestore_flags import FirestoreFeatureFlags  # noqa: PLC0415

    return FirestoreFeatureFlags(db=get_firestore_db())


# ============================================================
# Text Sanitizer
# ============================================================


@lru_cache
def get_text_sanitizer():
    """Get the text sanitizer. Currently: Bleach."""
    from app.services.sanitization.bleach_sanitizer import BleachSanitizer  # noqa: PLC0415

    return BleachSanitizer()


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
    return GeminiLLM(
        api_key=settings.gemini_api_key,
        model=settings.gemini_model,
        timeout_seconds=settings.gemini_timeout_seconds,
    )


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
        timeout_seconds=settings.embedding_timeout_seconds,
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
        timeout_seconds=settings.chromadb_timeout_seconds,
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
    """Get the edge classifier. Currently: LLM-based classification."""
    from app.services.ner.spacy_extractor import LLMEdgeClassifier  # noqa: PLC0415

    return LLMEdgeClassifier(llm=get_llm_provider())


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


def get_notification_sender():
    """Get the notification sender. Currently: Firebase Cloud Messaging."""
    from app.services.notification.fcm_sender import FCMNotificationSender  # noqa: PLC0415

    return FCMNotificationSender(user_repo=get_user_repository())


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


def get_review_state_repository():
    """Get the review state repository."""
    from app.repositories.review_state_repo import ReviewStateRepository  # noqa: PLC0415

    return ReviewStateRepository(db=get_firestore_db())


def get_quiz_attempt_repository():
    """Get the quiz attempt repository."""
    from app.repositories.quiz_attempt_repo import QuizAttemptRepository  # noqa: PLC0415

    return QuizAttemptRepository(db=get_firestore_db())


# ============================================================
# Knowledge Graph Services
# ============================================================


def get_graph_builder():
    """Get the KG graph builder service."""
    from app.services.knowledge_graph.graph_builder import GraphBuilder  # noqa: PLC0415

    return GraphBuilder(
        ner_extractor=get_ner_extractor(),
        edge_classifier=get_edge_classifier(),
        concept_repo=get_concept_repository(),
        relationship_repo=get_relationship_repository(),
        short_repo=get_short_repository(),
        settings=get_settings(),
    )


def get_graph_query_service():
    """Get the KG query service."""
    from app.services.knowledge_graph.query_service import GraphQueryService  # noqa: PLC0415

    return GraphQueryService(
        concept_repo=get_concept_repository(),
        relationship_repo=get_relationship_repository(),
        settings=get_settings(),
    )


# ============================================================
# Learning Services
# ============================================================


def get_review_manager():
    """Get the review session manager."""
    from app.services.learning.review_manager import ReviewManager  # noqa: PLC0415

    return ReviewManager(
        scheduler=get_spaced_repetition_scheduler(),
        review_state_repo=get_review_state_repository(),
        short_repo=get_short_repository(),
        graph_query_service=get_graph_query_service(),
        settings=get_settings(),
    )


def get_quiz_generator():
    """Get the quiz generator."""
    from app.services.learning.quiz_generator import QuizGenerator  # noqa: PLC0415

    return QuizGenerator(
        llm=get_llm_provider(),
        short_repo=get_short_repository(),
        graph_query_service=get_graph_query_service(),
    )


def get_flashcard_generator():
    """Get the flashcard generator."""
    from app.services.learning.flashcard_generator import FlashcardGenerator  # noqa: PLC0415

    return FlashcardGenerator(
        llm=get_llm_provider(),
        short_repo=get_short_repository(),
    )


# ============================================================
# Search Services
# ============================================================


def get_hybrid_search_service():
    """Get the hybrid search service (sparse + dense)."""
    from app.services.search.hybrid_search import HybridSearchService  # noqa: PLC0415

    return HybridSearchService(
        sparse_engine=get_sparse_search_engine(),
        vector_store=get_vector_store(),
        embedding_provider=get_embedding_provider(),
        short_repo=get_short_repository(),
        settings=get_settings(),
    )


# ============================================================
# RAG Services
# ============================================================


def get_rag_orchestrator():
    """Get the RAG orchestrator."""
    from app.services.rag.rag_orchestrator import RAGOrchestrator  # noqa: PLC0415

    return RAGOrchestrator(
        search_service=get_hybrid_search_service(),
        reranker=get_reranker(),
        llm=get_llm_provider(),
        embedding_provider=get_embedding_provider(),
        short_repo=get_short_repository(),
        settings=get_settings(),
    )


# ============================================================
# Analytics Services
# ============================================================


def get_analytics_aggregator():
    """Get the analytics aggregator."""
    from app.services.analytics.aggregator import AnalyticsAggregator  # noqa: PLC0415

    return AnalyticsAggregator(
        note_repo=get_note_repository(),
        short_repo=get_short_repository(),
        concept_repo=get_concept_repository(),
        review_state_repo=get_review_state_repository(),
        interaction_repo=get_interaction_repository(),
        quiz_attempt_repo=get_quiz_attempt_repository(),
        user_repo=get_user_repository(),
    )


# ============================================================
# Profile Services
# ============================================================


def get_profile_service():
    """Get the profile service."""
    from app.services.profile.profile_service import ProfileService  # noqa: PLC0415

    return ProfileService(
        user_repo=get_user_repository(),
        note_repo=get_note_repository(),
        short_repo=get_short_repository(),
        review_state_repo=get_review_state_repository(),
        concept_repo=get_concept_repository(),
        interaction_repo=get_interaction_repository(),
        bookmark_repo=get_bookmark_repository(),
        chunk_repo=get_chunk_repository(),
        quiz_attempt_repo=get_quiz_attempt_repository(),
    )


# ============================================================
# Bookmark Services
# ============================================================


def get_bookmark_service():
    """Get the bookmark service."""
    from app.services.bookmark.bookmark_service import BookmarkService  # noqa: PLC0415

    return BookmarkService(
        bookmark_repo=get_bookmark_repository(),
        short_repo=get_short_repository(),
    )


# ============================================================
# Source Services
# ============================================================


def get_source_service():
    """Get the source service."""
    from app.services.source.source_service import SourceService  # noqa: PLC0415

    return SourceService(source_repo=get_source_repository())


# ============================================================
# Module Services
# ============================================================


def get_module_service():
    """Get the module service."""
    from app.services.module.module_service import ModuleService  # noqa: PLC0415

    return ModuleService(
        module_repo=get_module_repository(),
        short_repo=get_short_repository(),
    )


# ============================================================
# Notification Services
# ============================================================


def get_notification_service():
    """Get the notification service."""
    from app.services.notification.notification_service import NotificationService  # noqa: PLC0415

    return NotificationService(
        notification_repo=get_notification_repository(),
        notification_sender=get_notification_sender(),
    )


# ============================================================
# Sync Services
# ============================================================


def get_sync_service():
    """Get the sync service."""
    from app.services.sync.sync_service import SyncService  # noqa: PLC0415

    return SyncService(
        interaction_repo=get_interaction_repository(),
        user_repo=get_user_repository(),
    )


# ============================================================
# Recommendation Services
# ============================================================


def get_recommendation_scorer():
    """Get the multi-factor recommendation scorer."""
    from app.services.recommendation.multi_factor_scorer import MultiFactorScorer  # noqa: PLC0415

    return MultiFactorScorer(
        user_repo=get_user_repository(),
        interaction_repo=get_interaction_repository(),
        review_state_repo=get_review_state_repository(),
        short_repo=get_short_repository(),
        settings=get_settings(),
    )


def get_feed_ranker():
    """Get the feed ranker."""
    from app.services.recommendation.feed_ranker import FeedRanker  # noqa: PLC0415

    return FeedRanker(
        scorer=get_recommendation_scorer(),
        short_repo=get_short_repository(),
        review_state_repo=get_review_state_repository(),
        interaction_repo=get_interaction_repository(),
    )


# ============================================================
# BKT Mastery Tracker
# ============================================================


def get_bkt_tracker():
    """Get the BKT mastery tracker."""
    from app.services.learning.bkt_tracker import BKTTracker  # noqa: PLC0415

    return BKTTracker(concept_repo=get_concept_repository())


# ============================================================
# Quiz Grader
# ============================================================


def get_quiz_grader():
    """Get the quiz grader (grades answers, persists attempts, updates BKT mastery)."""
    from app.services.learning.quiz_grader import QuizGrader  # noqa: PLC0415

    return QuizGrader(
        quiz_attempt_repo=get_quiz_attempt_repository(),
        bkt_tracker=get_bkt_tracker(),
        short_repo=get_short_repository(),
    )


# ============================================================
# Subscription Service
# ============================================================


def get_subscription_service():
    """Get the subscription service (quota enforcement)."""
    from app.services.subscription.subscription_service import SubscriptionService  # noqa: PLC0415

    return SubscriptionService(
        user_repo=get_user_repository(),
        note_repo=get_note_repository(),
        source_repo=get_source_repository(),
    )
