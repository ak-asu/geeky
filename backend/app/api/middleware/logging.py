"""Structured request/response logging middleware.

Logs all requests with timing, status, and user context in JSON format
compatible with Google Cloud Logging.
"""

from __future__ import annotations

import logging
import time

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response

logger = logging.getLogger("app.access")


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """Logs request method, path, status, and duration."""

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        start = time.perf_counter()

        response = await call_next(request)

        duration_ms = (time.perf_counter() - start) * 1000
        user_id = getattr(request.state, "user_id", "anonymous")
        correlation_id = getattr(request.state, "correlation_id", "unknown")

        logger.info(
            "%s %s %d %.1fms user=%s cid=%s",
            request.method,
            request.url.path,
            response.status_code,
            duration_ms,
            user_id,
            correlation_id,
        )

        return response
