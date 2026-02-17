"""Bookmark service — create, remove, and list bookmarked shorts.

Handles bookmark CRUD with duplicate prevention and short existence verification.
"""

from __future__ import annotations

import logging
from typing import Any

from app.exceptions import ShortNotFoundError

logger = logging.getLogger(__name__)


class BookmarkService:
    """Bookmark management service.

    Args:
        bookmark_repo: Bookmark document repository.
        short_repo: Short repository (for existence verification).
    """

    def __init__(
        self,
        *,
        bookmark_repo: Any,
        short_repo: Any,
    ) -> None:
        self._bookmark_repo = bookmark_repo
        self._short_repo = short_repo

    async def create_bookmark(self, user_id: str, short_id: str) -> dict:
        """Bookmark a short for later review.

        Verifies the short exists and prevents duplicate bookmarks.
        Returns the bookmark data.
        """
        # Verify short exists
        short = await self._short_repo.get(user_id, short_id)
        if not short:
            raise ShortNotFoundError(short_id)

        # Check for existing bookmark
        existing = await self._bookmark_repo.get_by_short(user_id, short_id)
        if existing:
            return {
                "id": existing.id,
                "shortId": short_id,
                "alreadyBookmarked": True,
            }

        # Create bookmark
        from app.models.bookmark import BookmarkDocument  # noqa: PLC0415

        bookmark = BookmarkDocument(short_id=short_id)
        doc_id = await self._bookmark_repo.create(user_id, bookmark)

        return {
            "id": doc_id,
            "shortId": short_id,
            "alreadyBookmarked": False,
        }

    async def remove_bookmark(self, user_id: str, short_id: str) -> bool:
        """Remove a bookmark by short ID.

        Returns True if the bookmark was found and deleted, False otherwise.
        """
        return await self._bookmark_repo.delete_by_short(user_id, short_id)

    async def list_bookmarks(
        self, user_id: str, limit: int = 50, cursor: str | None = None
    ) -> tuple[list[dict], str | None]:
        """List bookmarked shorts with pagination.

        Returns:
            Tuple of (bookmark items with short metadata, next_cursor).
        """
        bookmarks, next_cursor = await self._bookmark_repo.list(
            user_id, limit=limit, cursor=cursor
        )

        items = []
        for bookmark in bookmarks:
            short = await self._short_repo.get(user_id, bookmark.short_id)
            item = {
                "id": bookmark.id,
                "shortId": bookmark.short_id,
                "createdAt": bookmark.created_at.isoformat() if bookmark.created_at else None,
            }
            if short:
                item["short"] = {
                    "title": short.title,
                    "summary": short.summary,
                    "topics": short.topics,
                    "difficulty": short.difficulty,
                }
            items.append(item)

        return items, next_cursor
