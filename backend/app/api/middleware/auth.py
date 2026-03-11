"""Firebase token verification middleware.

Extracts and verifies Firebase ID tokens from the Authorization header.
Injects the authenticated user_id into the request state.
"""

from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass
from typing import Annotated

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.exceptions import AuthenticationError, ExternalServiceError

logger = logging.getLogger(__name__)

_bearer_scheme = HTTPBearer(auto_error=False)


@dataclass
class TokenClaims:
    """Decoded Firebase token claims with user identity fields."""

    uid: str
    name: str
    email: str
    avatar_url: str


async def _decode_token(credentials: HTTPAuthorizationCredentials | None) -> dict:
    """Shared token verification logic. Returns the raw decoded claims dict."""
    if credentials is None:
        raise AuthenticationError("Missing authorization header")

    token = credentials.credentials

    try:
        from firebase_admin import auth  # noqa: PLC0415

        # verify_id_token is synchronous and may fetch Google's public keys on
        # first call — run in a thread to avoid blocking the event loop.
        decoded_token: dict = await asyncio.to_thread(auth.verify_id_token, token)
        return decoded_token
    except ImportError:
        logger.warning("firebase_admin not available, using dev mode auth")
        raise AuthenticationError("Firebase not configured")
    except Exception as exc:
        # Distinguish token-level rejections from infrastructure failures so
        # callers receive the correct HTTP status (401 vs 503) and so that
        # programming errors (AttributeError, etc.) are not silently masked.
        try:
            from firebase_admin import auth as _fb_auth  # noqa: PLC0415

            _token_errors = (
                _fb_auth.InvalidIdTokenError,
                _fb_auth.ExpiredIdTokenError,
                _fb_auth.RevokedIdTokenError,
                _fb_auth.UserDisabledError,
                _fb_auth.CertificateFetchError,
            )
        except ImportError:
            _token_errors = ()  # type: ignore[assignment]

        if isinstance(exc, _token_errors):
            logger.warning("Token verification rejected: %s: %s", type(exc).__name__, exc)
            raise AuthenticationError("Invalid or expired token") from exc

        # Anything else (network error, timeout, unexpected exception) is an
        # infrastructure failure — log as ERROR and surface as 503, not 401.
        logger.error(
            "Firebase auth infrastructure error: %s: %s",
            type(exc).__name__,
            exc,
            exc_info=True,
        )
        raise ExternalServiceError("Firebase", str(exc)) from exc


async def verify_firebase_token(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_scheme),
) -> str:
    """Verify Firebase ID token and return the user's UID.

    Used as a FastAPI dependency on all protected routes.

    Returns:
        The authenticated user's Firebase UID.

    Raises:
        AuthenticationError: If the token is missing, invalid, or expired.
    """
    decoded = await _decode_token(credentials)
    return decoded["uid"]


async def verify_firebase_claims(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_scheme),
) -> TokenClaims:
    """Verify Firebase ID token and return full identity claims.

    Used on routes that need to auto-create a user profile (upsert on first
    sign-in), since the token carries the user's name, email, and avatar URL.

    Returns:
        TokenClaims with uid, name, email, and avatar_url.

    Raises:
        AuthenticationError: If the token is missing, invalid, or expired.
    """
    decoded = await _decode_token(credentials)
    return TokenClaims(
        uid=decoded["uid"],
        name=decoded.get("name", ""),
        email=decoded.get("email", ""),
        avatar_url=decoded.get("picture", ""),
    )


# Type aliases for dependency injection in route handlers
CurrentUserId = Annotated[str, Depends(verify_firebase_token)]
CurrentUserClaims = Annotated[TokenClaims, Depends(verify_firebase_claims)]
