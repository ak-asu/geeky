"""Base repository Protocol and Firestore implementation.

All repositories follow this pattern:
- Protocol defines the interface (for testing/swapping)
- FirestoreBaseRepository provides common Firestore CRUD operations
- Concrete repos extend FirestoreBaseRepository with entity-specific logic

CRITICAL: Every method requires user_id as first parameter for data isolation.
NOTE: firebase_admin returns a sync Firestore client; all SDK calls are wrapped
with asyncio.to_thread() to avoid blocking the event loop.
"""

from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone
from typing import Any, Generic, TypeVar

from pydantic import BaseModel

logger = logging.getLogger(__name__)

T = TypeVar("T", bound=BaseModel)


class FirestoreBaseRepository(Generic[T]):
    """Base repository for Firestore CRUD operations.

    Provides common create/get/list/update/delete operations
    scoped to a user's subcollection.

    Args:
        db: Firestore client instance (sync firebase_admin client).
        collection_name: Name of the subcollection under users/{userId}/.
        model_class: Pydantic model class for deserialization.
    """

    def __init__(self, db: Any, collection_name: str, model_class: type[T]) -> None:
        self._db = db
        self._collection_name = collection_name
        self._model_class = model_class

    def _user_collection(self, user_id: str):
        """Get the user-scoped subcollection reference."""
        return self._db.collection("users").document(user_id).collection(self._collection_name)

    async def get(self, user_id: str, doc_id: str) -> T | None:
        """Get a single document by ID, scoped to user."""
        doc_ref = self._user_collection(user_id).document(doc_id)
        doc = await asyncio.to_thread(doc_ref.get)
        if not doc.exists:
            return None
        data = doc.to_dict()
        data["id"] = doc.id
        return self._model_class.model_validate(data)

    async def list(
        self,
        user_id: str,
        limit: int = 50,
        cursor: str | None = None,
        order_by: str = "createdAt",
        direction: str = "DESCENDING",
    ) -> tuple[list[T], str | None]:
        """List documents with cursor-based pagination, scoped to user.

        Returns:
            Tuple of (items, next_cursor). next_cursor is None if no more items.
        """
        from google.cloud.firestore_v1 import Query  # noqa: PLC0415

        query = self._user_collection(user_id).order_by(
            order_by,
            direction=Query.DESCENDING if direction == "DESCENDING" else Query.ASCENDING,
        )

        if cursor:
            cursor_doc = await asyncio.to_thread(
                self._user_collection(user_id).document(cursor).get
            )
            if cursor_doc.exists:
                query = query.start_after(cursor_doc)

        query = query.limit(limit + 1)  # Fetch one extra to check for next page
        docs = await asyncio.to_thread(lambda: list(query.stream()))

        has_more = len(docs) > limit
        if has_more:
            docs = docs[:limit]

        items = []
        for doc in docs:
            data = doc.to_dict()
            data["id"] = doc.id
            items.append(self._model_class.model_validate(data))

        next_cursor = docs[-1].id if has_more and docs else None
        return items, next_cursor

    async def create(self, user_id: str, data: T, doc_id: str | None = None) -> str:
        """Create a new document, scoped to user.

        Returns:
            The document ID.
        """
        doc_data = data.model_dump(exclude_none=True, mode="json")
        doc_data["createdAt"] = datetime.now(timezone.utc)
        doc_data["updatedAt"] = datetime.now(timezone.utc)

        if doc_id:
            await asyncio.to_thread(
                self._user_collection(user_id).document(doc_id).set, doc_data
            )
            return doc_id
        else:
            _, doc_ref = await asyncio.to_thread(
                self._user_collection(user_id).add, doc_data
            )
            return doc_ref.id

    async def update(self, user_id: str, doc_id: str, data: dict) -> None:
        """Update specific fields of a document, scoped to user."""
        data["updatedAt"] = datetime.now(timezone.utc)
        await asyncio.to_thread(
            self._user_collection(user_id).document(doc_id).update, data
        )

    async def delete(self, user_id: str, doc_id: str) -> None:
        """Delete a document, scoped to user."""
        await asyncio.to_thread(self._user_collection(user_id).document(doc_id).delete)

    async def count(self, user_id: str) -> int:
        """Count documents in the user's subcollection."""
        query = self._user_collection(user_id)
        count_result = await asyncio.to_thread(lambda: query.count().get())
        return count_result[0][0].value if count_result else 0

    async def query(
        self,
        user_id: str,
        filters: list[tuple[str, str, Any]] | None = None,
        order_by: str | None = None,
        limit: int = 50,
    ) -> list[T]:
        """Query documents with filters, scoped to user.

        Args:
            filters: List of (field, operator, value) tuples.
                     Operators: ==, !=, <, <=, >, >=, in, array_contains
        """
        q = self._user_collection(user_id)

        if filters:
            for field, op, value in filters:
                q = q.where(field, op, value)

        if order_by:
            q = q.order_by(order_by)

        q = q.limit(limit)
        docs = await asyncio.to_thread(lambda: list(q.stream()))

        items = []
        for doc in docs:
            data = doc.to_dict()
            data["id"] = doc.id
            items.append(self._model_class.model_validate(data))

        return items
