"""Redis connection for Celery and rate limiting."""

from __future__ import annotations

import logging
from functools import lru_cache

logger = logging.getLogger(__name__)


@lru_cache
def get_redis_url() -> str:
    """Get Redis connection URL from settings."""
    from app.config import get_settings  # noqa: PLC0415

    return get_settings().redis_url
