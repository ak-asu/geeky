"""Quiz repository."""
from __future__ import annotations
from datetime import datetime, timezone
from typing import Any
from app.models.quiz import QuizCardDocument
from app.repositories.base import FirestoreBaseRepository

class QuizRepository(FirestoreBaseRepository[QuizCardDocument]):
    def __init__(self, db: Any) -> None:
        super().__init__(db, "quiz_cards", QuizCardDocument)

    async def get_due_cards(self, user_id: str, limit: int = 20) -> list[QuizCardDocument]:
        now = datetime.now(timezone.utc).isoformat()
        return await self.query(
            user_id,
            filters=[("dueDate", "<=", now)],
            order_by="dueDate",
            limit=limit,
        )
