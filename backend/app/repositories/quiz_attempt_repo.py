"""Quiz attempt repository for tracking quiz history."""
from __future__ import annotations

from typing import Any

from app.models.quiz_attempt import QuizAttemptDocument
from app.repositories.base import FirestoreBaseRepository


class QuizAttemptRepository(FirestoreBaseRepository[QuizAttemptDocument]):
    def __init__(self, db: Any) -> None:
        super().__init__(db, "quiz_attempts", QuizAttemptDocument)

    async def get_by_short(self, user_id: str, short_id: str) -> list[QuizAttemptDocument]:
        """Get all attempts that include a specific short."""
        return await self.query(user_id, filters=[("shortIds", "array_contains", short_id)])

    async def get_recent(self, user_id: str, limit: int = 10) -> list[QuizAttemptDocument]:
        """Get most recent quiz attempts."""
        items, _ = await self.list(user_id, limit=limit, order_by="createdAt", direction="DESCENDING")
        return items
