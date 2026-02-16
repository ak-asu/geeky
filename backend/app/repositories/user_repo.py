"""User repository.

Unlike other repos, users are stored at the top level: users/{userId}
rather than as subcollections.
"""
from __future__ import annotations
import logging
from datetime import datetime, timezone
from typing import Any
from app.models.user import UserDocument

logger = logging.getLogger(__name__)

class UserRepository:
    def __init__(self, db: Any) -> None:
        self._db = db

    def _collection(self):
        return self._db.collection("users")

    async def get(self, user_id: str) -> UserDocument | None:
        doc = self._collection().document(user_id).get()
        if not doc.exists:
            return None
        data = doc.to_dict()
        data["id"] = doc.id
        return UserDocument.model_validate(data)

    async def create(self, user_id: str, data: UserDocument) -> str:
        doc_data = data.model_dump(exclude_none=True, mode="json")
        doc_data["createdAt"] = datetime.now(timezone.utc)
        doc_data["updatedAt"] = datetime.now(timezone.utc)
        self._collection().document(user_id).set(doc_data)
        return user_id

    async def update(self, user_id: str, data: dict) -> None:
        data["updatedAt"] = datetime.now(timezone.utc)
        self._collection().document(user_id).update(data)

    async def delete(self, user_id: str) -> None:
        self._collection().document(user_id).delete()
