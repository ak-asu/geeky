"""Per-user rate limiting middleware.

Uses Redis for distributed rate limit counters.
Supports daily limits (SE-05: 1000/day) and burst limits.
"""

from __future__ import annotations

import logging
import time
from typing import Annotated, Any

from fastapi import Depends

from app.api.middleware.auth import CurrentUserId
from app.config import Settings, get_settings
from app.exceptions import RateLimitExceededError

logger = logging.getLogger(__name__)

# In-memory fallback when Redis is unavailable
_local_counters: dict[str, list[float]] = {}

# ---------------------------------------------------------------------------
# Connection pool registry
# ---------------------------------------------------------------------------
# Keyed by (redis_url, socket_timeout) so each unique combination gets exactly
# one pool, regardless of how many RateLimiter instances are created.  The
# pool outlives individual request/RateLimiter instances and is never closed
# mid-request.  Using a plain dict is safe because dict access in CPython is
# GIL-protected; duplicate pool creation on the very first concurrent pair of
# requests is harmless (both pools are identical and one is discarded).
_pool_registry: dict[tuple[str, float], Any] = {}


def _get_or_create_pool(redis_url: str, socket_timeout: float) -> Any:
    """Return a shared ``ConnectionPool`` for this (url, timeout) pair."""
    import redis.asyncio as aioredis  # noqa: PLC0415

    key = (redis_url, socket_timeout)
    if key not in _pool_registry:
        _pool_registry[key] = aioredis.ConnectionPool.from_url(
            redis_url,
            decode_responses=True,
            socket_timeout=socket_timeout,
            socket_connect_timeout=socket_timeout,
            max_connections=20,
        )
    return _pool_registry[key]


class RateLimiter:
    """Token-bucket rate limiter with Redis backend and in-memory fallback."""

    def __init__(self, settings: Settings) -> None:
        self._daily_limit = settings.rate_limit_per_day
        self._burst_limit = settings.rate_limit_burst
        self._redis_url = settings.redis_url
        self._socket_timeout = settings.redis_socket_timeout_seconds

    async def check(self, user_id: str) -> None:
        """Check if user is within rate limits. Raises RateLimitExceededError if not."""
        try:
            await self._check_redis(user_id)
        except RateLimitExceededError:
            raise  # never swallow limit violations — always propagate to the caller
        except ImportError:
            self._check_local(user_id)
        except Exception:
            # Redis unavailable — fall back to local burst-only check
            logger.warning(
                "Redis unavailable for rate limiting (user=%s) — falling back to in-memory counter",
                user_id,
                exc_info=True,
            )
            self._check_local(user_id)

    async def _check_redis(self, user_id: str) -> None:
        """Check rate limit using Redis counters.

        Borrows a connection from the shared pool (M1: no new connection per
        request).  ``r.aclose()`` returns the connection to the pool — it does
        NOT tear down the pool itself.
        """
        import redis.asyncio as aioredis  # noqa: PLC0415

        pool = _get_or_create_pool(self._redis_url, self._socket_timeout)
        r = aioredis.Redis(connection_pool=pool)
        try:
            daily_key = f"rate:{user_id}:daily"
            burst_key = f"rate:{user_id}:burst"

            pipe = r.pipeline()

            # Daily counter — expires at midnight
            pipe.incr(daily_key)
            pipe.ttl(daily_key)

            # Burst counter — sliding window of 60 seconds
            pipe.incr(burst_key)
            pipe.ttl(burst_key)

            results = await pipe.execute()
            daily_count, daily_ttl, burst_count, burst_ttl = results

            # Set TTL if new key
            if daily_ttl == -1:
                await r.expire(daily_key, 86400)  # 24 hours
            if burst_ttl == -1:
                await r.expire(burst_key, 60)  # 1 minute

            if daily_count > self._daily_limit:
                raise RateLimitExceededError()
            if burst_count > self._burst_limit:
                raise RateLimitExceededError()
        finally:
            await r.aclose()

    def _check_local(self, user_id: str) -> None:
        """In-memory rate limit check (single-instance fallback)."""
        now = time.time()
        key = f"burst:{user_id}"

        if key not in _local_counters:
            _local_counters[key] = []

        # Clean old entries (older than 60s)
        _local_counters[key] = [t for t in _local_counters[key] if now - t < 60]
        _local_counters[key].append(now)

        if len(_local_counters[key]) > self._burst_limit:
            raise RateLimitExceededError()


def get_rate_limiter(settings: Settings = Depends(get_settings)) -> RateLimiter:
    """Factory for rate limiter dependency."""
    return RateLimiter(settings)


async def check_rate_limit(
    user_id: CurrentUserId,
    limiter: RateLimiter = Depends(get_rate_limiter),
) -> None:
    """Dependency that checks rate limits for the authenticated user."""
    await limiter.check(user_id)


CheckRateLimit = Annotated[None, Depends(check_rate_limit)]
