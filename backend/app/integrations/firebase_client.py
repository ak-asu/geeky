"""Firebase Admin SDK initialization and helpers.

Provides lazy-initialized Firebase app and Firestore client.
Uses service account credentials from environment or file path.
"""

from __future__ import annotations

import logging
from functools import lru_cache
from typing import Any

logger = logging.getLogger(__name__)

_firebase_app = None


def get_firebase_app() -> Any:
    """Get or initialize the Firebase Admin app.

    Uses credentials from:
    1. FIREBASE_CREDENTIALS_PATH setting (explicit file path)
    2. GOOGLE_APPLICATION_CREDENTIALS env var (standard GCP)
    3. Default credentials (Cloud Run, GCE, etc.)
    """
    global _firebase_app  # noqa: PLW0603
    if _firebase_app is not None:
        return _firebase_app

    import firebase_admin  # noqa: PLC0415
    from firebase_admin import credentials  # noqa: PLC0415

    from app.config import get_settings  # noqa: PLC0415

    settings = get_settings()

    try:
        if settings.firebase_credentials_path:
            cred = credentials.Certificate(settings.firebase_credentials_path)
            _firebase_app = firebase_admin.initialize_app(cred)
        elif settings.firebase_project_id:
            _firebase_app = firebase_admin.initialize_app(
                options={"projectId": settings.firebase_project_id}
            )
        else:
            # Use Application Default Credentials
            _firebase_app = firebase_admin.initialize_app()

        logger.info("Firebase Admin SDK initialized successfully")
        return _firebase_app
    except ValueError:
        # Already initialized
        _firebase_app = firebase_admin.get_app()
        return _firebase_app


@lru_cache
def get_firestore_client() -> Any:
    """Get the Firestore client instance."""
    from firebase_admin import firestore  # noqa: PLC0415

    get_firebase_app()
    return firestore.client()
