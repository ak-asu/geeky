"""Source service — manage external content sources (RSS, URLs, newsletters).

Handles source CRUD, health checking, and status management.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any

import httpx

from app.exceptions import SourceNotFoundError
from app.models.source import SourceCreate, SourceDocument

logger = logging.getLogger(__name__)


class SourceService:
    """External source management service.

    Args:
        source_repo: Source document repository.
    """

    def __init__(self, *, source_repo: Any) -> None:
        self._source_repo = source_repo

    async def add_source(self, user_id: str, data: SourceCreate) -> SourceDocument:
        """Add a new external source.

        Creates a SourceDocument with initial health_score=1.0 and active status.
        """
        source = SourceDocument(
            type=data.type,
            name=data.name,
            url=data.url,
            fetch_frequency=data.fetch_frequency,
            default_topics=data.default_topics,
            content_filters=data.content_filters,
        )

        doc_id = await self._source_repo.create(user_id, source)
        source.id = doc_id
        return source

    async def list_sources(self, user_id: str) -> list[SourceDocument]:
        """List all sources for the user."""
        return await self._source_repo.query(user_id, limit=200)

    async def get_source(self, user_id: str, source_id: str) -> SourceDocument:
        """Get a single source by ID."""
        source = await self._source_repo.get(user_id, source_id)
        if not source:
            raise SourceNotFoundError(source_id)
        return source

    async def remove_source(self, user_id: str, source_id: str) -> None:
        """Remove a source by ID."""
        source = await self._source_repo.get(user_id, source_id)
        if not source:
            raise SourceNotFoundError(source_id)
        await self._source_repo.delete(user_id, source_id)

    async def check_health(self, user_id: str, source_id: str) -> dict:
        """Check if a source URL is reachable and update health status.

        Performs an HTTP HEAD request and updates health_score and last_checked.
        """
        source = await self._source_repo.get(user_id, source_id)
        if not source:
            raise SourceNotFoundError(source_id)

        health_score = 0.0
        status = "error"
        error_detail = None

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.head(source.url, follow_redirects=True)
                if resp.status_code < 400:
                    health_score = 1.0
                    status = "active"
                else:
                    health_score = 0.0
                    status = "error"
                    error_detail = f"HTTP {resp.status_code}"
        except httpx.TimeoutException:
            error_detail = "Request timed out"
        except httpx.RequestError as exc:
            error_detail = str(exc)

        now_iso = datetime.now(timezone.utc).isoformat()
        update_data = {
            "healthScore": health_score,
            "lastChecked": now_iso,
            "status": status,
        }
        await self._source_repo.update(user_id, source_id, update_data)

        return {
            "sourceId": source_id,
            "healthScore": health_score,
            "status": status,
            "lastChecked": now_iso,
            "error": error_detail,
        }
