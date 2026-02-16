"""Application configuration via pydantic-settings.

All configuration is loaded from environment variables or .env file.
No hardcoded values — everything is configurable.
"""

from __future__ import annotations

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # --- App ---
    app_name: str = "Geeky API"
    app_version: str = "0.1.0"
    debug: bool = False
    environment: str = Field(default="development", description="development | staging | production")
    log_level: str = "INFO"
    cors_origins: list[str] = Field(default=["*"])

    # --- Firebase ---
    firebase_credentials_path: str | None = Field(
        default=None,
        description="Path to Firebase service account JSON. If None, uses GOOGLE_APPLICATION_CREDENTIALS env var.",
    )
    firebase_project_id: str | None = None

    # --- Gemini AI ---
    gemini_api_key: str = Field(default="", description="Google Gemini API key")
    gemini_model: str = Field(default="gemini-2.5-flash", description="Gemini model for generation")
    gemini_embedding_model: str = Field(default="models/embedding-001", description="Gemini embedding model")
    gemini_embedding_dimensions: int = Field(default=768, description="Embedding vector dimensions")

    # --- ChromaDB ---
    chromadb_host: str = Field(default="localhost", description="ChromaDB server host")
    chromadb_port: int = Field(default=8001, description="ChromaDB server port")
    chromadb_collection_name: str = Field(default="geeky_chunks", description="Shared ChromaDB collection name")

    # --- Redis / Celery ---
    redis_url: str = Field(default="redis://localhost:6379/0", description="Redis connection URL")
    celery_broker_url: str = Field(default="redis://localhost:6379/0", description="Celery broker URL")
    celery_result_backend: str = Field(default="redis://localhost:6379/1", description="Celery result backend URL")

    # --- Rate Limiting ---
    rate_limit_per_day: int = Field(default=1000, description="Max API calls per user per day (SE-05)")
    rate_limit_burst: int = Field(default=50, description="Max burst requests per minute")

    # --- Pipeline ---
    pipeline_max_concurrent: int = Field(default=10, description="Max concurrent note processing (SC-04)")
    pipeline_timeout_seconds: int = Field(default=30, description="Pipeline task timeout")
    chunk_target_words: int = Field(default=1000, description="Target words per chunk")
    chunk_overlap_words: int = Field(default=200, description="Overlap words between chunks")
    dedup_semantic_threshold: float = Field(default=0.85, description="ChromaDB cosine threshold for semantic dedup")
    dedup_near_threshold: float = Field(default=0.9, description="Jaccard threshold for near-duplicate dedup")
    anti_density_max_per_source: int = Field(default=50, description="Max shorts per source (CP-17)")

    # --- RAG ---
    rag_top_k: int = Field(default=10, description="Default top-k for retrieval")
    rag_mmr_lambda: float = Field(default=0.7, description="MMR diversity parameter (RQ-08)")
    rag_context_max_tokens: int = Field(default=4000, description="Max tokens for RAG context window")
    rag_redundancy_threshold: float = Field(default=0.92, description="Cosine threshold for redundancy pruning")

    # --- Recommendation ---
    rec_weight_relevance: float = Field(default=0.4, description="Relevance weight (AL-02)")
    rec_weight_capability: float = Field(default=0.3, description="Capability weight (AL-02)")
    rec_weight_novelty: float = Field(default=0.3, description="Novelty weight (AL-02)")

    # --- Spaced Repetition ---
    fsrs_desired_retention: float = Field(default=0.9, description="FSRS target retention rate")

    # --- Source Polling ---
    source_poll_interval_minutes: int = Field(default=60, description="Source polling interval (SYS-02)")


@lru_cache
def get_settings() -> Settings:
    """Cached settings singleton."""
    return Settings()
