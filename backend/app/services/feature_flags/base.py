"""FeatureFlagProvider Protocol — contract for feature flag services."""

from __future__ import annotations

from typing import Any, Protocol


class FeatureFlagProvider(Protocol):
    """Reads feature flags from a remote store with local caching.

    Flags are stored in Firestore at ``app_config/global`` under a ``flags``
    map.  Implementations must cache aggressively to avoid hot-spotting
    Firestore on every request.
    """

    async def is_enabled(self, flag: str, *, default: bool = False) -> bool:
        """Return True if the named flag is enabled.

        Args:
            flag: Feature flag name (e.g. ``"rag_enabled"``).
            default: Value to return when the flag is absent.
        """
        ...

    async def get_value(self, flag: str, *, default: Any = None) -> Any:
        """Return the raw value of a flag (any JSON-serialisable type).

        Args:
            flag: Feature flag name.
            default: Value to return when the flag is absent.
        """
        ...
