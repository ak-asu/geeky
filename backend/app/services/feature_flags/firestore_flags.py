"""FirestoreFeatureFlags — reads flags from Firestore app_config/global.

Flags document structure:
    {
        "flags": {
            "rag_enabled": true,
            "quiz_generation_enabled": true,
            "pipeline_enabled": true,
            "max_notes_free": 50
        }
    }

Uses an in-process TTL cache (default 5 minutes) to avoid Firestore
hot-spotting on every API request.
"""

from __future__ import annotations

import asyncio
import logging
import time
from typing import Any

logger = logging.getLogger(__name__)

_FLAGS_COLLECTION = "app_config"
_FLAGS_DOCUMENT = "global"
_FLAGS_FIELD = "flags"


class FirestoreFeatureFlags:
    """Feature flags backed by Firestore with TTL caching.

    Satisfies the :class:`FeatureFlagProvider` Protocol.
    """

    def __init__(self, db, *, ttl_seconds: float = 300.0) -> None:
        """
        Args:
            db: Sync Firestore Admin client (firebase_admin.firestore.client()).
            ttl_seconds: How long to cache the flags map (default 5 min).
        """
        self._db = db
        self._ttl = ttl_seconds
        self._cache: dict[str, Any] = {}
        self._cache_loaded_at: float = 0.0

    async def is_enabled(self, flag: str, *, default: bool = False) -> bool:
        """Return True if the named flag is enabled."""
        flags = await self._get_flags()
        value = flags.get(flag, default)
        return bool(value)

    async def get_value(self, flag: str, *, default: Any = None) -> Any:
        """Return the raw value of a flag."""
        flags = await self._get_flags()
        return flags.get(flag, default)

    async def _get_flags(self) -> dict[str, Any]:
        """Return cached flags, refreshing from Firestore when TTL expires."""
        now = time.monotonic()
        if now - self._cache_loaded_at < self._ttl and self._cache:
            return self._cache

        try:
            doc_ref = self._db.collection(_FLAGS_COLLECTION).document(_FLAGS_DOCUMENT)
            doc = await asyncio.to_thread(doc_ref.get)
            if doc.exists:
                data = doc.to_dict() or {}
                self._cache = data.get(_FLAGS_FIELD, {})
            else:
                self._cache = {}
            self._cache_loaded_at = now
            logger.debug("Feature flags refreshed: %d flags loaded", len(self._cache))
        except Exception as exc:
            logger.warning("Failed to load feature flags from Firestore: %s", exc)
            # Return stale cache if available, else empty dict
        return self._cache
