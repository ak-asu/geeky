"""Unit tests for RateLimiter.

Covers audit findings:
  C1  — socket_timeout / socket_connect_timeout passed to ConnectionPool.from_url
  C2  — RateLimitExceededError must propagate through check(), never be swallowed
        by the generic `except Exception` fallback branch.
  M1  — Connection pool is shared across calls, not created per request.
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.api.middleware.rate_limit import RateLimiter, _local_counters, _pool_registry
from app.exceptions import RateLimitExceededError


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_limiter(
    *,
    daily_limit: int = 1000,
    burst_limit: int = 50,
    redis_url: str = "redis://localhost:6379/0",
    socket_timeout: float = 2.0,
) -> RateLimiter:
    settings = MagicMock()
    settings.rate_limit_per_day = daily_limit
    settings.rate_limit_burst = burst_limit
    settings.redis_url = redis_url
    settings.redis_socket_timeout_seconds = socket_timeout
    return RateLimiter(settings)


def _make_redis_mock(
    daily_count: int = 1,
    daily_ttl: int = 3600,
    burst_count: int = 1,
    burst_ttl: int = 60,
) -> MagicMock:
    """Build a mock Redis client whose pipeline returns the given counter values."""
    pipe = MagicMock()
    pipe.execute = AsyncMock(return_value=[daily_count, daily_ttl, burst_count, burst_ttl])
    r = MagicMock()
    r.pipeline.return_value = pipe
    r.expire = AsyncMock()
    r.aclose = AsyncMock()
    return r


# ---------------------------------------------------------------------------
# Fixture — clear module-level state between tests
# ---------------------------------------------------------------------------


@pytest.fixture(autouse=True)
def clear_module_state():
    _local_counters.clear()
    _pool_registry.clear()
    yield
    _local_counters.clear()
    _pool_registry.clear()


# ---------------------------------------------------------------------------
# C2: RateLimitExceededError must propagate — never be swallowed
# ---------------------------------------------------------------------------


class TestRateLimitExceededPropagates:
    """C2 fix: RateLimitExceededError raised inside _check_redis must bubble out
    of check() and never be caught by the generic `except Exception` fallback."""

    async def test_daily_limit_exceeded_raises(self) -> None:
        limiter = _make_limiter(daily_limit=5, burst_limit=100)
        r = _make_redis_mock(daily_count=6, daily_ttl=3600, burst_count=1, burst_ttl=60)

        with patch("redis.asyncio.ConnectionPool.from_url", return_value=MagicMock()), \
             patch("redis.asyncio.Redis", return_value=r):
            with pytest.raises(RateLimitExceededError):
                await limiter.check("user-daily-exceeded")

    async def test_burst_limit_exceeded_raises(self) -> None:
        limiter = _make_limiter(daily_limit=1000, burst_limit=3)
        r = _make_redis_mock(daily_count=1, daily_ttl=3600, burst_count=4, burst_ttl=60)

        with patch("redis.asyncio.ConnectionPool.from_url", return_value=MagicMock()), \
             patch("redis.asyncio.Redis", return_value=r):
            with pytest.raises(RateLimitExceededError):
                await limiter.check("user-burst-exceeded")

    async def test_within_limits_does_not_raise(self) -> None:
        limiter = _make_limiter(daily_limit=1000, burst_limit=50)
        r = _make_redis_mock(daily_count=1, daily_ttl=3600, burst_count=1, burst_ttl=60)

        with patch("redis.asyncio.ConnectionPool.from_url", return_value=MagicMock()), \
             patch("redis.asyncio.Redis", return_value=r):
            await limiter.check("user-ok")  # must not raise

    async def test_redis_connection_closed_after_limit_exceeded(self) -> None:
        """The finally block in _check_redis must always call aclose(), even on exception."""
        limiter = _make_limiter(daily_limit=2, burst_limit=100)
        r = _make_redis_mock(daily_count=3, daily_ttl=3600, burst_count=1, burst_ttl=60)

        with patch("redis.asyncio.ConnectionPool.from_url", return_value=MagicMock()), \
             patch("redis.asyncio.Redis", return_value=r):
            with pytest.raises(RateLimitExceededError):
                await limiter.check("user-close-on-exc")

        r.aclose.assert_awaited_once()


# ---------------------------------------------------------------------------
# Redis unavailable — must fall back gracefully, not hard-error
# ---------------------------------------------------------------------------


class TestRedisFallback:
    """When Redis raises any non-limit exception, check() falls back to the
    in-memory burst counter rather than propagating the infrastructure error."""

    async def test_connection_error_falls_back(self) -> None:
        limiter = _make_limiter(burst_limit=100)

        with patch("redis.asyncio.ConnectionPool.from_url", side_effect=ConnectionError("Redis down")):
            await limiter.check("user-conn-err")  # no exception

    async def test_pipeline_execute_error_falls_back(self) -> None:
        limiter = _make_limiter(burst_limit=100)
        r = _make_redis_mock()
        r.pipeline.return_value.execute = AsyncMock(side_effect=OSError("pipe broken"))

        with patch("redis.asyncio.ConnectionPool.from_url", return_value=MagicMock()), \
             patch("redis.asyncio.Redis", return_value=r):
            await limiter.check("user-pipe-err")  # no exception

    async def test_fallback_enforces_burst_when_exceeded(self) -> None:
        """Even in fallback mode, burst violations must be caught."""
        limiter = _make_limiter(burst_limit=2)

        with patch("redis.asyncio.ConnectionPool.from_url", side_effect=ConnectionError("Redis down")):
            limiter._check_local("user-local-x")
            limiter._check_local("user-local-x")
            with pytest.raises(RateLimitExceededError):
                # 3rd call in the same window exceeds burst_limit=2
                limiter._check_local("user-local-x")

    async def test_import_error_falls_back_to_local(self) -> None:
        """ImportError (redis package absent) triggers in-memory fallback, not a crash."""
        limiter = _make_limiter(burst_limit=100)

        with patch.dict("sys.modules", {"redis": None, "redis.asyncio": None}):
            # The lazy `import redis.asyncio as aioredis` raises ImportError
            await limiter.check("user-no-redis-pkg")  # no exception


# ---------------------------------------------------------------------------
# C1: Socket timeout is wired into the Redis connection pool
# ---------------------------------------------------------------------------


class TestSocketTimeout:
    """C1 fix: socket_timeout and socket_connect_timeout must be forwarded to
    ConnectionPool.from_url so connections never hang indefinitely."""

    async def test_socket_timeouts_passed_to_pool(self) -> None:
        limiter = _make_limiter(socket_timeout=1.5)
        r = _make_redis_mock()

        with patch("redis.asyncio.ConnectionPool.from_url", return_value=MagicMock()) as mock_pool, \
             patch("redis.asyncio.Redis", return_value=r):
            await limiter.check("user-timeout-kwarg")

        mock_pool.assert_called_once_with(
            limiter._redis_url,
            decode_responses=True,
            socket_timeout=1.5,
            socket_connect_timeout=1.5,
            max_connections=20,
        )

    async def test_socket_timeout_reflects_settings(self) -> None:
        """The timeout value stored on RateLimiter matches the settings field."""
        limiter = _make_limiter(socket_timeout=3.0)
        assert limiter._socket_timeout == 3.0

    async def test_default_socket_timeout_is_bounded(self) -> None:
        """Default timeout (2.0 s) is tight enough to not block request handling."""
        limiter = _make_limiter()  # uses default 2.0
        assert limiter._socket_timeout <= 5.0, "socket timeout should be well under 5 s"


# ---------------------------------------------------------------------------
# M1: Connection pool is reused — not created per request
# ---------------------------------------------------------------------------


class TestConnectionPoolReuse:
    """M1 fix: a new ConnectionPool must not be created for every request.
    The pool is keyed by (url, timeout) and lives at module level."""

    async def test_pool_reused_on_second_call(self) -> None:
        limiter = _make_limiter()
        r = _make_redis_mock()

        with patch("redis.asyncio.ConnectionPool.from_url", return_value=MagicMock()) as mock_pool, \
             patch("redis.asyncio.Redis", return_value=r):
            await limiter.check("user-1")
            await limiter.check("user-1")

        # Pool created only once — reused on the second call
        mock_pool.assert_called_once()

    async def test_different_urls_get_separate_pools(self) -> None:
        limiter_a = _make_limiter(redis_url="redis://host-a:6379/0")
        limiter_b = _make_limiter(redis_url="redis://host-b:6379/0")
        r = _make_redis_mock()

        with patch("redis.asyncio.ConnectionPool.from_url", return_value=MagicMock()) as mock_pool, \
             patch("redis.asyncio.Redis", return_value=r):
            await limiter_a.check("user-a")
            await limiter_b.check("user-b")

        # Two distinct URLs → two separate pool creation calls
        assert mock_pool.call_count == 2


# ---------------------------------------------------------------------------
# TTL initialisation — new keys get expiry set
# ---------------------------------------------------------------------------


class TestTTLInitialisation:
    """Keys with TTL=-1 (freshly created) must have an expiry applied."""

    async def test_new_daily_key_gets_expire(self) -> None:
        limiter = _make_limiter()
        # TTL=-1 signals a brand-new key with no expiry
        r = _make_redis_mock(daily_count=1, daily_ttl=-1, burst_count=1, burst_ttl=60)

        with patch("redis.asyncio.ConnectionPool.from_url", return_value=MagicMock()), \
             patch("redis.asyncio.Redis", return_value=r):
            await limiter.check("user-new-daily")

        # expire must be called for the daily key (86 400 s = 24 h)
        calls = {call.args[1] for call in r.expire.call_args_list}
        assert 86400 in calls

    async def test_new_burst_key_gets_expire(self) -> None:
        limiter = _make_limiter()
        r = _make_redis_mock(daily_count=1, daily_ttl=3600, burst_count=1, burst_ttl=-1)

        with patch("redis.asyncio.ConnectionPool.from_url", return_value=MagicMock()), \
             patch("redis.asyncio.Redis", return_value=r):
            await limiter.check("user-new-burst")

        calls = {call.args[1] for call in r.expire.call_args_list}
        assert 60 in calls

    async def test_existing_keys_do_not_reset_ttl(self) -> None:
        limiter = _make_limiter()
        r = _make_redis_mock(daily_count=1, daily_ttl=3600, burst_count=1, burst_ttl=30)

        with patch("redis.asyncio.ConnectionPool.from_url", return_value=MagicMock()), \
             patch("redis.asyncio.Redis", return_value=r):
            await limiter.check("user-existing-keys")

        r.expire.assert_not_awaited()
