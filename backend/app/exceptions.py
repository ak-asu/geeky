"""Domain exception hierarchy.

Services raise these exceptions. The error handler middleware
maps them to appropriate HTTP responses. Never return raw traces to clients.
"""

from __future__ import annotations


class GeekyError(Exception):
    """Base exception for all domain errors."""

    def __init__(self, message: str, code: str = "INTERNAL_ERROR", detail: str | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.code = code
        self.detail = detail


# --- Not Found ---


class NotFoundError(GeekyError):
    """Resource not found."""

    def __init__(self, resource: str, resource_id: str) -> None:
        super().__init__(
            message=f"{resource} not found: {resource_id}",
            code="NOT_FOUND",
            detail=f"The requested {resource.lower()} does not exist.",
        )
        self.resource = resource
        self.resource_id = resource_id


class NoteNotFoundError(NotFoundError):
    def __init__(self, note_id: str) -> None:
        super().__init__("Note", note_id)


class ShortNotFoundError(NotFoundError):
    def __init__(self, short_id: str) -> None:
        super().__init__("Short", short_id)


class ModuleNotFoundError(NotFoundError):
    def __init__(self, module_id: str) -> None:
        super().__init__("Module", module_id)


class ConceptNotFoundError(NotFoundError):
    def __init__(self, concept_id: str) -> None:
        super().__init__("Concept", concept_id)


class SourceNotFoundError(NotFoundError):
    def __init__(self, source_id: str) -> None:
        super().__init__("Source", source_id)


class QuizCardNotFoundError(NotFoundError):
    def __init__(self, card_id: str) -> None:
        super().__init__("QuizCard", card_id)


class ReviewStateNotFoundError(NotFoundError):
    def __init__(self, review_state_id: str) -> None:
        super().__init__("ReviewState", review_state_id)


# --- Knowledge Graph ---


class KnowledgeGraphError(GeekyError):
    """Knowledge graph operation error."""

    def __init__(self, message: str) -> None:
        super().__init__(message=message, code="KG_ERROR")


# --- Auth ---


class AuthenticationError(GeekyError):
    """Authentication failure."""

    def __init__(self, message: str = "Authentication required") -> None:
        super().__init__(message=message, code="UNAUTHENTICATED")


class AuthorizationError(GeekyError):
    """Authorization failure — user doesn't own this resource."""

    def __init__(self, message: str = "Access denied") -> None:
        super().__init__(message=message, code="FORBIDDEN")


# --- Rate Limiting ---


class RateLimitExceededError(GeekyError):
    """User exceeded rate limit."""

    def __init__(self) -> None:
        super().__init__(
            message="Rate limit exceeded",
            code="RATE_LIMIT_EXCEEDED",
            detail="You have exceeded the maximum number of API calls. Please try again later.",
        )


# --- Processing ---


class ProcessingError(GeekyError):
    """Content processing pipeline error."""

    def __init__(self, message: str, stage: str | None = None) -> None:
        super().__init__(message=message, code="PROCESSING_ERROR", detail=f"Failed at stage: {stage}" if stage else None)
        self.stage = stage


class ExtractionError(ProcessingError):
    """Document extraction failure."""

    def __init__(self, message: str) -> None:
        super().__init__(message=message, stage="extraction")


class ChunkingError(ProcessingError):
    """Chunking failure."""

    def __init__(self, message: str) -> None:
        super().__init__(message=message, stage="chunking")


class EmbeddingError(ProcessingError):
    """Embedding generation failure."""

    def __init__(self, message: str) -> None:
        super().__init__(message=message, stage="embedding")


# --- Validation ---


class ValidationError(GeekyError):
    """Input validation error."""

    def __init__(self, message: str) -> None:
        super().__init__(message=message, code="VALIDATION_ERROR")


# --- External Service ---


class ExternalServiceError(GeekyError):
    """External service (Gemini, ChromaDB, etc.) failure."""

    def __init__(self, service: str, message: str) -> None:
        super().__init__(
            message=f"{service} error: {message}",
            code="EXTERNAL_SERVICE_ERROR",
            detail=f"The external service '{service}' is currently unavailable.",
        )
        self.service = service


# --- Subscription ---


class PremiumRequiredError(GeekyError):
    """Feature requires premium subscription."""

    def __init__(self, feature: str) -> None:
        super().__init__(
            message=f"Premium subscription required for: {feature}",
            code="PREMIUM_REQUIRED",
            detail=f"Upgrade to premium to access {feature}.",
        )
        self.feature = feature
