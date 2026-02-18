"""Shared mock services for integration tests.

Provides no-op overrides for infrastructure dependencies (rate limiting,
feature flags) that would otherwise try to connect to Redis/Firebase in tests.
"""

from __future__ import annotations

from typing import Any


class MockFeatureFlags:
    """Feature flag provider that enables all flags by default."""

    async def is_enabled(self, flag: str, default: bool = False) -> bool:
        return True

    async def get_value(self, flag: str, default: Any = None) -> Any:
        return default


async def noop_rate_limit() -> None:
    """No-op rate limit check for tests — always passes."""
    return None
