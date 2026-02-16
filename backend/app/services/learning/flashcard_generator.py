"""Flashcard generator — creates Anki-style flashcards from Shorts.

Generates front/back cards with optional cloze deletions and
bidirectional cards for key concept pairs.
"""
from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass, field
from typing import TYPE_CHECKING

from pydantic import BaseModel, Field

if TYPE_CHECKING:
    from app.repositories.short_repo import ShortRepository
    from app.services.llm.base import LLMProvider

logger = logging.getLogger(__name__)


@dataclass
class Flashcard:
    """A single flashcard."""
    id: str = ""
    front: str = ""
    back: str = ""
    short_id: str = ""
    card_type: str = "basic"  # basic, cloze, bidirectional
    difficulty: float = 0.5
    tags: list[str] = field(default_factory=list)


class _GeneratedFlashcards(BaseModel):
    """Structured LLM response for flashcard generation."""
    cards: list[_GeneratedCard] = Field(default_factory=list)


class _GeneratedCard(BaseModel):
    """A single generated flashcard."""
    front: str = ""
    back: str = ""
    card_type: str = Field(default="basic", alias="cardType")
    difficulty: float = 0.5
    tags: list[str] = Field(default_factory=list)
    model_config = {"populate_by_name": True}


class FlashcardGenerator:
    """Generates flashcards from Short content using LLM.

    Supports:
    - Basic front/back cards
    - Cloze deletion cards
    - Bidirectional cards for concept pairs

    Dependencies:
    - llm: LLM provider for card generation
    - short_repo: Access to short content
    """

    def __init__(
        self,
        *,
        llm: LLMProvider,
        short_repo: ShortRepository,
    ) -> None:
        self._llm = llm
        self._short_repo = short_repo

    async def generate(
        self,
        user_id: str,
        short_ids: list[str],
        *,
        cards_per_short: int = 3,
        include_cloze: bool = True,
        include_bidirectional: bool = True,
    ) -> list[Flashcard]:
        """Generate flashcards from a list of shorts.

        Args:
            user_id: User ID for data access.
            short_ids: Shorts to generate cards from.
            cards_per_short: Target number of cards per short.
            include_cloze: Whether to include cloze deletion cards.
            include_bidirectional: Whether to include bidirectional cards.

        Returns:
            List of Flashcard objects.
        """
        all_cards: list[Flashcard] = []

        for short_id in short_ids:
            short = await self._short_repo.get(user_id, short_id)
            if short is None:
                continue

            card_types = ["basic"]
            if include_cloze:
                card_types.append("cloze")
            if include_bidirectional:
                card_types.append("bidirectional")

            type_descriptions = ", ".join(card_types)

            prompt = (
                f"Create exactly {cards_per_short} flashcards from this content.\n\n"
                f"Title: {short.title}\n"
                f"Content: {short.content}\n\n"
                f"Card types to use: {type_descriptions}\n"
                f"For 'basic': front is a question, back is the answer.\n"
                f"For 'cloze': front has a blank (___) where a key term should be, back is the complete text.\n"
                f"For 'bidirectional': front asks 'What is X?', and a reverse card asks 'X is known as?'.\n"
                f"Vary difficulty (0.3=easy, 0.9=hard). Include relevant topic tags."
            )

            try:
                result = await self._llm.generate_structured(
                    prompt,
                    _GeneratedFlashcards,
                    system="You are an expert educator creating effective flashcards for active recall.",
                    temperature=0.5,
                )

                for gc in result.cards[:cards_per_short]:
                    card = Flashcard(
                        id=str(uuid.uuid4()),
                        front=gc.front,
                        back=gc.back,
                        short_id=short_id,
                        card_type=gc.card_type if gc.card_type in card_types else "basic",
                        difficulty=max(0.0, min(1.0, gc.difficulty)),
                        tags=gc.tags or short.topics[:3],
                    )
                    all_cards.append(card)

                    # Generate reverse card for bidirectional
                    if gc.card_type == "bidirectional":
                        reverse_card = Flashcard(
                            id=str(uuid.uuid4()),
                            front=gc.back,
                            back=gc.front,
                            short_id=short_id,
                            card_type="bidirectional_reverse",
                            difficulty=gc.difficulty,
                            tags=gc.tags or short.topics[:3],
                        )
                        all_cards.append(reverse_card)

            except Exception:
                logger.exception("Flashcard generation failed for short %s", short_id)

        return all_cards
