"""Profile service — user profile management, stats, export, deletion.

Handles CRUD for user profiles, learning statistics summary,
GDPR-compliant data export, and cascading account deletion.
"""

from __future__ import annotations

import logging
from typing import Any

from app.exceptions import UserNotFoundError
from app.models.user import UserDocument, UserProfileUpdate

logger = logging.getLogger(__name__)


class ProfileService:
    """User profile management service.

    Args:
        user_repo: User document repository.
        note_repo: Note repository (for stats/export/delete).
        short_repo: Short repository.
        review_state_repo: Review state repository.
        concept_repo: Concept repository.
        interaction_repo: Interaction repository.
        bookmark_repo: Bookmark repository.
        chunk_repo: Chunk repository.
        quiz_attempt_repo: Quiz attempt repository.
    """

    def __init__(
        self,
        *,
        user_repo: Any,
        note_repo: Any,
        short_repo: Any,
        review_state_repo: Any,
        concept_repo: Any,
        interaction_repo: Any,
        bookmark_repo: Any,
        chunk_repo: Any,
        quiz_attempt_repo: Any,
    ) -> None:
        self._user_repo = user_repo
        self._note_repo = note_repo
        self._short_repo = short_repo
        self._review_state_repo = review_state_repo
        self._concept_repo = concept_repo
        self._interaction_repo = interaction_repo
        self._bookmark_repo = bookmark_repo
        self._chunk_repo = chunk_repo
        self._quiz_attempt_repo = quiz_attempt_repo

    async def get_profile(self, user_id: str) -> UserDocument:
        """Get user profile by ID."""
        user = await self._user_repo.get(user_id, user_id)
        if not user:
            raise UserNotFoundError(user_id)
        return user

    async def update_profile(
        self, user_id: str, update: UserProfileUpdate
    ) -> UserDocument:
        """Update user profile fields (partial update)."""
        # Verify user exists
        user = await self._user_repo.get(user_id, user_id)
        if not user:
            raise UserNotFoundError(user_id)

        # Build update dict from non-None fields
        update_data = update.model_dump(
            exclude_none=True, mode="json", by_alias=True
        )

        if update_data:
            await self._user_repo.update(user_id, user_id, update_data)

        # Return updated profile
        return await self.get_profile(user_id)

    async def get_stats(self, user_id: str) -> dict:
        """Get lightweight learning statistics summary."""
        user = await self._user_repo.get(user_id, user_id)
        if not user:
            raise UserNotFoundError(user_id)

        note_count = await self._note_repo.count(user_id)
        short_count = await self._short_repo.count(user_id)
        concept_count = await self._concept_repo.count(user_id)
        review_count = await self._review_state_repo.count(user_id)

        return {
            "totalNotes": note_count,
            "totalShorts": short_count,
            "totalConcepts": concept_count,
            "totalReviewStates": review_count,
            "streak": {
                "current": user.streak.current,
                "longest": user.streak.longest,
            },
        }

    async def export_data(self, user_id: str) -> dict:
        """Export all user data (GDPR compliance).

        Returns a dict with all user data organized by collection.
        """
        user = await self._user_repo.get(user_id, user_id)
        if not user:
            raise UserNotFoundError(user_id)

        # Gather all user data
        notes = await self._note_repo.query(user_id, limit=5000)
        shorts = await self._short_repo.query(user_id, limit=5000)
        concepts = await self._concept_repo.query(user_id, limit=5000)
        review_states = await self._review_state_repo.query(user_id, limit=5000)
        interactions = await self._interaction_repo.query(user_id, limit=5000)
        quiz_attempts = await self._quiz_attempt_repo.query(user_id, limit=5000)

        return {
            "profile": user.model_dump(mode="json", by_alias=True),
            "notes": [n.model_dump(mode="json", by_alias=True) for n in notes],
            "shorts": [s.model_dump(mode="json", by_alias=True) for s in shorts],
            "concepts": [c.model_dump(mode="json", by_alias=True) for c in concepts],
            "reviewStates": [r.model_dump(mode="json", by_alias=True) for r in review_states],
            "interactions": [i.model_dump(mode="json", by_alias=True) for i in interactions],
            "quizAttempts": [q.model_dump(mode="json", by_alias=True) for q in quiz_attempts],
            "exportedAt": _utc_now_iso(),
        }

    async def delete_account(self, user_id: str) -> None:
        """Delete user account and all associated data (cascade).

        Deletes all subcollections for the user.
        """
        user = await self._user_repo.get(user_id, user_id)
        if not user:
            raise UserNotFoundError(user_id)

        logger.warning("Deleting account for user %s", user_id)

        # Delete all subcollection data
        repos_to_clear = [
            ("interactions", self._interaction_repo),
            ("quiz_attempts", self._quiz_attempt_repo),
            ("review_states", self._review_state_repo),
            ("bookmarks", self._bookmark_repo),
            ("chunks", self._chunk_repo),
            ("shorts", self._short_repo),
            ("concepts", self._concept_repo),
            ("notes", self._note_repo),
        ]

        for collection_name, repo in repos_to_clear:
            try:
                items = await repo.query(user_id, limit=5000)
                for item in items:
                    await repo.delete(user_id, item.id)
                logger.info("Deleted %d %s for user %s", len(items), collection_name, user_id)
            except Exception as exc:
                logger.error("Failed to delete %s for user %s: %s", collection_name, user_id, exc)

        # Finally delete the user document
        await self._user_repo.delete(user_id, user_id)
        logger.info("Account deletion completed for user %s", user_id)


def _utc_now_iso() -> str:
    """Get current UTC time as ISO string."""
    from datetime import datetime, timezone  # noqa: PLC0415

    return datetime.now(timezone.utc).isoformat()
