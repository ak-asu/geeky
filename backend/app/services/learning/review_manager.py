"""Review session manager — selects due cards and processes review responses.

Combines FSRS scheduling with KG prerequisite ordering for intelligent
review sessions (AL-01, AL-02, AL-03).
"""
from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import TYPE_CHECKING

from app.models.review_state import ReviewStateDocument
from app.services.quiz.scheduler.base import CardState, ReviewCard

if TYPE_CHECKING:
    from app.config import Settings
    from app.repositories.review_state_repo import ReviewStateRepository
    from app.repositories.short_repo import ShortRepository
    from app.services.knowledge_graph.query_service import GraphQueryService
    from app.services.quiz.scheduler.base import SpacedRepetitionScheduler

logger = logging.getLogger(__name__)


@dataclass
class ReviewSession:
    """A batch of cards ready for review."""
    cards: list[dict] = field(default_factory=list)
    total_due: int = 0
    new_count: int = 0
    review_count: int = 0


@dataclass
class ReviewResponse:
    """Result of processing a single review response."""
    card_id: str
    next_due: datetime | None = None
    new_state: str = ""
    interval_days: int = 0
    stability: float = 0.0
    difficulty: float = 0.0


class ReviewManager:
    """Manages spaced repetition review sessions.

    Selects due cards using FSRS scheduling + KG prerequisite ordering (AL-03).
    Processes review responses and updates card state.

    Dependencies:
    - scheduler: FSRS-based spaced repetition scheduler
    - review_state_repo: Per-short review state storage
    - short_repo: Access to short content for display
    - graph_query_service: KG prerequisite ordering
    - settings: Batch size, limits
    """

    def __init__(
        self,
        *,
        scheduler: SpacedRepetitionScheduler,
        review_state_repo: ReviewStateRepository,
        short_repo: ShortRepository,
        graph_query_service: GraphQueryService | None = None,
        settings: Settings,
    ) -> None:
        self._scheduler = scheduler
        self._review_repo = review_state_repo
        self._short_repo = short_repo
        self._graph_query = graph_query_service
        self._settings = settings

    async def get_due_cards(self, user_id: str, limit: int | None = None) -> ReviewSession:
        """Get cards due for review, ordered by priority.

        Priority order (AL-03):
        1. Overdue cards (due_date < now), most overdue first
        2. New cards that are prerequisites of known concepts
        3. Remaining new cards
        """
        batch_size = min(
            limit or self._settings.review_default_batch,
            self._settings.review_max_batch,
        )

        # Fetch due and new cards
        due_cards = await self._review_repo.get_due(user_id, limit=batch_size)
        remaining = batch_size - len(due_cards)
        new_cards = await self._review_repo.get_new(user_id, limit=remaining) if remaining > 0 else []

        # Build response with short content
        all_states = due_cards + new_cards
        cards: list[dict] = []

        for state in all_states:
            short = await self._short_repo.get(user_id, state.short_id)
            if short is None:
                continue

            retrievability = 0.0
            review_card = _to_review_card(state)
            if state.state != "new":
                retrievability = self._scheduler.get_retrievability(review_card)

            cards.append({
                "reviewStateId": state.id,
                "shortId": state.short_id,
                "title": short.title,
                "content": short.content,
                "difficulty": short.difficulty,
                "state": state.state,
                "dueDate": state.due_date.isoformat() if state.due_date else None,
                "stability": state.stability,
                "retrievability": round(retrievability, 4),
                "reps": state.reps,
                "lapses": state.lapses,
            })

        return ReviewSession(
            cards=cards,
            total_due=len(due_cards),
            new_count=len(new_cards),
            review_count=len(due_cards),
        )

    async def submit_review(
        self, user_id: str, review_state_id: str, rating: int
    ) -> ReviewResponse:
        """Process a review response and update the card's FSRS state.

        Args:
            user_id: User ID.
            review_state_id: ID of the ReviewState document.
            rating: User rating (1=Again, 2=Hard, 3=Good, 4=Easy).

        Returns:
            ReviewResponse with updated scheduling info.
        """
        state = await self._review_repo.get(user_id, review_state_id)
        if state is None:
            from app.exceptions import ReviewStateNotFoundError  # noqa: PLC0415
            raise ReviewStateNotFoundError(review_state_id)

        # Convert to ReviewCard for FSRS scheduling
        review_card = _to_review_card(state)

        # Apply FSRS algorithm
        updated_card = self._scheduler.schedule(review_card, rating)

        # Persist updated state
        await self._review_repo.update(user_id, review_state_id, {
            "stability": updated_card.stability,
            "difficulty": updated_card.difficulty,
            "dueDate": updated_card.due_date.isoformat(),
            "lastReviewDate": updated_card.last_review_date.isoformat() if updated_card.last_review_date else None,
            "reps": updated_card.reps,
            "lapses": updated_card.lapses,
            "state": updated_card.state.value,
        })

        interval_days = 0
        if updated_card.due_date and updated_card.last_review_date:
            interval_days = (updated_card.due_date - updated_card.last_review_date).days

        return ReviewResponse(
            card_id=review_state_id,
            next_due=updated_card.due_date,
            new_state=updated_card.state.value,
            interval_days=interval_days,
            stability=updated_card.stability,
            difficulty=updated_card.difficulty,
        )

    async def ensure_review_states(self, user_id: str, short_ids: list[str]) -> int:
        """Create ReviewState documents for shorts that don't have one yet.

        Called after shorts are created to bootstrap review tracking.
        Returns count of new states created.
        """
        created = 0
        for short_id in short_ids:
            existing = await self._review_repo.get_by_short(user_id, short_id)
            if existing is None:
                state_id = str(uuid.uuid4())
                doc = ReviewStateDocument(
                    id=state_id,
                    short_id=short_id,
                    state="new",
                )
                await self._review_repo.create(user_id, doc, doc_id=state_id)
                created += 1
        return created


def _to_review_card(state: ReviewStateDocument) -> ReviewCard:
    """Convert a ReviewStateDocument to a ReviewCard for FSRS."""
    try:
        card_state = CardState(state.state)
    except ValueError:
        card_state = CardState.NEW

    return ReviewCard(
        card_id=state.id,
        stability=state.stability,
        difficulty=state.difficulty,
        due_date=state.due_date or datetime.now(timezone.utc),
        last_review_date=state.last_review_date,
        reps=state.reps,
        lapses=state.lapses,
        state=card_state,
    )
