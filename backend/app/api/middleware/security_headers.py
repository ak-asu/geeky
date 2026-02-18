"""Security headers middleware.

Adds standard security headers to every response:
- X-Content-Type-Options: nosniff
- X-Frame-Options: DENY
- Referrer-Policy: strict-origin-when-cross-origin
- Permissions-Policy: restricts camera, microphone, geolocation
- Strict-Transport-Security: on HTTPS connections only

These headers protect against common browser-based attacks (XSS, clickjacking,
MIME-type sniffing, information leakage).
"""

from __future__ import annotations

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Middleware that appends security headers to every HTTP response."""

    async def dispatch(self, request: Request, call_next) -> Response:
        response = await call_next(request)

        response.headers.setdefault("X-Content-Type-Options", "nosniff")
        response.headers.setdefault("X-Frame-Options", "DENY")
        # XSS-Protection is deprecated in modern browsers; CSP is preferred.
        # Set to "0" to avoid IE's quirky XSS filter triggering false positives.
        response.headers.setdefault("X-XSS-Protection", "0")
        response.headers.setdefault(
            "Referrer-Policy", "strict-origin-when-cross-origin"
        )
        response.headers.setdefault(
            "Permissions-Policy",
            "camera=(), microphone=(), geolocation=(), payment=()",
        )

        # HSTS — only meaningful on HTTPS; skip on plain HTTP (local dev)
        if request.url.scheme == "https":
            response.headers.setdefault(
                "Strict-Transport-Security",
                "max-age=31536000; includeSubDomains",
            )

        return response
