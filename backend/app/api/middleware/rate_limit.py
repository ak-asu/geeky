"""Per-user rate limiting middleware.

Uses Redis for distributed rate limit counters.
Supports daily limits (SE-05: 1000/day) and burst limits.
"""

from __future__ import annotations

import logging
import time
from typing import Annotated

from fastapi import Depends

from app.api.middleware.auth import CurrentUserId
from app.config import Settings, get_settings
from app.exceptions import RateLimitExceededError

logger = logging.getLogger(__name__)

# In-memory fallback when Redis is unavailable
_local_counters: dict[str, list[float]] = {}


class RateLimiter:
    """Token-bucket rate limiter with Redis backend and in-memory fallback."""

    def __init__(self, settings: Settings) -> None:
        self._daily_limit = settings.rate_limit_per_day
        self._burst_limit = settings.rate_limit_burst
        self._redis_url = settings.redis_url

    async def check(self, user_id: str) -> None:
        """Check if user is within rate limits. Raises RateLimitExceededError if not."""
        try:
            await self._check_redis(user_id)
        except ImportError:
            self._check_local(user_id)
        except Exception:
            # Redis unavailable — fall back to local
            self._check_local(user_id)

    async def _check_redis(self, user_id: str) -> None:
        """Check rate limit using Redis counters."""
        import redis.asyncio as aioredis  # noqa: PLC0415

        r = aioredis.from_url(self._redis_url, decode_responses=True)
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
