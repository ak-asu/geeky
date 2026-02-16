"""Review state repository for FSRS spaced repetition tracking."""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from app.models.review_state import ReviewStateDocument
from app.repositories.base import FirestoreBaseRepository


class ReviewStateRepository(FirestoreBaseRepository[ReviewStateDocument]):
    def __init__(self, db: Any) -> None:
        super().__init__(db, "review_states", ReviewStateDocument)

    async def get_by_short(self, user_id: str, short_id: str) -> ReviewStateDocument | None:
        results = await self.query(user_id, filters=[("shortId", "==", short_id)], limit=1)
        return results[0] if results else None

    async def get_due(self, user_id: str, limit: int = 20) -> list[ReviewStateDocument]:
        """Get review states where due_date <= now, ordered by due date."""
        now = datetime.now(timezone.utc).isoformat()
        return await self.query(
            user_id,
            filters=[("dueDate", "<=", now)],
            order_by="dueDate",
            limit=limit,
        )

    async def get_new(self, user_id: str, limit: int = 10) -> list[ReviewStateDocument]:
        """Get cards in 'new' state that have never been reviewed."""
        return await self.query(
            user_id,
            filters=[("state", "==", "new")],
            limit=limit,
        )
