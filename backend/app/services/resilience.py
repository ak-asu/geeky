"""Resilience utilities — timeouts and fallbacks using stdlib only.

These are thin wrappers around ``asyncio.wait_for`` that provide
consistent timeout handling and optional fallback values.

Usage:
    result = await with_timeout(
        some_coroutine(),
        timeout_seconds=10.0,
        fallback=[],
    )

    result = await with_fallback(
        primary_coroutine(),
        fallback_coroutine(),
        error_types=(ServiceUnavailableError,),
    )
"""

from __future__ import annotations

import asyncio
import logging
from collections.abc import Awaitable, Callable, Coroutine
from typing import Any, TypeVar

logger = logging.getLogger(__name__)

T = TypeVar("T")


async def with_timeout(
    coro: Coroutine[Any, Any, T],
    *,
    timeout_seconds: float,
    fallback: T | None = None,
    operation_name: str = "operation",
) -> T | None:
    """Run *coro* with a timeout, returning *fallback* on timeout.

    Args:
        coro: Awaitable to execute.
        timeout_seconds: Maximum wall-clock seconds to wait.
        fallback: Value returned on ``asyncio.TimeoutError``. If ``None``
                  and ``fallback`` is intentionally ``None``, the caller
                  receives ``None``; if you need to distinguish pass a
                  sentinel.
        operation_name: Human-readable label used in log messages.

    Returns:
        Coroutine result on success, *fallback* on timeout.

    Raises:
        Any exception other than ``asyncio.TimeoutError`` propagates normally.
    """
    try:
        return await asyncio.wait_for(coro, timeout=timeout_seconds)
    except asyncio.TimeoutError:
        logger.warning(
            "%s timed out after %.1fs — using fallback",
            operation_name,
            timeout_seconds,
        )
        return fallback


async def with_fallback(
    primary_coro: Coroutine[Any, Any, T],
    fallback_coro: Coroutine[Any, Any, T] | Callable[[], Awaitable[T]],
    *,
    error_types: tuple[type[Exception], ...] = (Exception,),
    operation_name: str = "operation",
) -> T:
    """Try *primary_coro*, fall back to *fallback_coro* on specified errors.

    Args:
        primary_coro: Preferred path.
        fallback_coro: Backup coroutine or zero-argument async callable.
        error_types: Exception types that trigger the fallback.
        operation_name: Human-readable label for log messages.

    Returns:
        Result of the primary or fallback coroutine.

    Raises:
        Any exception that occurs in the fallback propagates to the caller.
    """
    try:
        return await primary_coro
    except error_types as exc:
        logger.warning(
            "%s primary path failed (%s: %s) — using fallback",
            operation_name,
            type(exc).__name__,
            exc,
        )
        if callable(fallback_coro) and not asyncio.iscoroutine(fallback_coro):
            return await fallback_coro()
        return await fallback_coro  # type: ignore[return-value]


async def with_timeout_or_raise(
    coro: Coroutine[Any, Any, T],
    *,
    timeout_seconds: float,
    operation_name: str = "operation",
) -> T:
    """Run *coro* with a timeout, re-raising ``asyncio.TimeoutError`` on expiry.

    Use this when the caller *must* know that the operation failed rather
    than silently receiving a fallback.
    """
    try:
        return await asyncio.wait_for(coro, timeout=timeout_seconds)
    except asyncio.TimeoutError:
        logger.error("%s timed out after %.1fs", operation_name, timeout_seconds)
        raise
