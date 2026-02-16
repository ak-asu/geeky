"""Firebase token verification middleware.

Extracts and verifies Firebase ID tokens from the Authorization header.
Injects the authenticated user_id into the request state.
"""

from __future__ import annotations

import logging
from typing import Annotated

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.exceptions import AuthenticationError

logger = logging.getLogger(__name__)

_bearer_scheme = HTTPBearer(auto_error=False)


async def _get_firebase_app():
    """Lazy import and return the Firebase app instance."""
    from app.integrations.firebase_client import get_firebase_app

    return get_firebase_app()


async def verify_firebase_token(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_scheme),
) -> str:
    """Verify Firebase ID token and return the user's UID.

    This is used as a FastAPI dependency on protected routes.

    Returns:
        The authenticated user's Firebase UID.

    Raises:
        AuthenticationError: If the token is missing, invalid, or expired.
    """
    if credentials is None:
        raise AuthenticationError("Missing authorization header")

    token = credentials.credentials

    try:
        from firebase_admin import auth  # noqa: PLC0415

        decoded_token = auth.verify_id_token(token)
        uid: str = decoded_token["uid"]
        return uid
    except ImportError:
        # Firebase not initialized — dev/test mode fallback
        logger.warning("firebase_admin not available, using dev mode auth")
        raise AuthenticationError("Firebase not configured")
    except Exception as exc:
        logger.warning("Token verification failed: %s", exc)
        raise AuthenticationError("Invalid or expired token")


# Type alias for dependency injection in route handlers
CurrentUserId = Annotated[str, Depends(verify_firebase_token)]
