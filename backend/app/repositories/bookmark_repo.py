"""Bookmark repository."""
from __future__ import annotations
from typing import Any
from app.models.bookmark import BookmarkDocument
from app.repositories.base import FirestoreBaseRepository

class BookmarkRepository(FirestoreBaseRepository[BookmarkDocument]):
    def __init__(self, db: Any) -> None:
        super().__init__(db, "bookmarks", BookmarkDocument)

    async def get_by_short(self, user_id: str, short_id: str) -> BookmarkDocument | None:
        results = await self.query(user_id, filters=[("shortId", "==", short_id)], limit=1)
        return results[0] if results else None

    async def delete_by_short(self, user_id: str, short_id: str) -> bool:
        bookmark = await self.get_by_short(user_id, short_id)
        if bookmark:
            await self.delete(user_id, bookmark.id)
            return True
        return False
