"""Analytics repository.

Analytics data is computed on-the-fly from interactions and other collections.
This repository provides helper methods for aggregation queries.
"""
from __future__ import annotations
from typing import Any

class AnalyticsRepository:
    def __init__(self, db: Any) -> None:
        self._db = db

    async def get_interaction_count(self, user_id: str, interaction_type: str | None = None) -> int:
        query = self._db.collection("users").document(user_id).collection("interactions")
        if interaction_type:
            query = query.where("type", "==", interaction_type)
        count_result = query.count().get()
        return count_result[0][0].value if count_result else 0
