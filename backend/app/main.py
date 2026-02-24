"""FastAPI application factory.

Creates and configures the FastAPI app with middleware, exception handlers,
and route registration.
"""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from typing import AsyncIterator

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.router import api_router
from app.config import get_settings
from app.exceptions import (
    AuthenticationError,
    AuthorizationError,
    GeekyError,
    NotFoundError,
    PremiumRequiredError,
    RateLimitExceededError,
    ValidationError,
)

logger = logging.getLogger(__name__)


def _configure_logging(log_level: str) -> None:
    """Configure structured JSON logging for Cloud Logging compatibility."""
    level = getattr(logging, log_level.upper(), logging.INFO)
    try:
        from pythonjsonlogger import jsonlogger  # noqa: PLC0415

        handler = logging.StreamHandler()
        formatter = jsonlogger.JsonFormatter(
            fmt="%(asctime)s %(levelname)s %(name)s %(message)s",
            rename_fields={"asctime": "timestamp", "levelname": "level"},
        )
        handler.setFormatter(formatter)
        logging.basicConfig(level=level, handlers=[handler], force=True)
    except ImportError:
        # Fall back to plain text logging if python-json-logger not installed
        logging.basicConfig(
            level=level,
            format="%(asctime)s %(levelname)s %(name)s %(message)s",
        )


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Application lifespan: startup and shutdown hooks."""
    settings = get_settings()
    _configure_logging(settings.log_level)
    logger.info("Starting %s v%s [%s]", settings.app_name, settings.app_version, settings.environment)
    yield
    logger.info("Shutting down %s", settings.app_name)


def create_app() -> FastAPI:
    """Create and configure the FastAPI application."""
    settings = get_settings()

    app = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
        docs_url="/docs" if settings.debug else None,
        redoc_url="/redoc" if settings.debug else None,
        lifespan=lifespan,
    )

    # --- CORS ---
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.allowed_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "X-Correlation-ID"],
    )

    # --- Middleware ---
    from app.api.middleware.error_handler import CorrelationIdMiddleware  # noqa: PLC0415
    from app.api.middleware.logging import RequestLoggingMiddleware  # noqa: PLC0415
    from app.api.middleware.security_headers import SecurityHeadersMiddleware  # noqa: PLC0415

    app.add_middleware(SecurityHeadersMiddleware)
    app.add_middleware(RequestLoggingMiddleware)
    app.add_middleware(CorrelationIdMiddleware)

    # --- Exception Handlers ---
    _register_exception_handlers(app)

    # --- Routes ---
    app.include_router(api_router)

    return app


def _register_exception_handlers(app: FastAPI) -> None:
    """Register global exception handlers mapping domain errors to HTTP responses."""

    @app.exception_handler(NotFoundError)
    async def not_found_handler(_request: Request, exc: NotFoundError) -> JSONResponse:
        return JSONResponse(
            status_code=404,
            content={"error": {"code": exc.code, "message": exc.message, "detail": exc.detail}},
        )

    @app.exception_handler(AuthenticationError)
    async def auth_handler(_request: Request, exc: AuthenticationError) -> JSONResponse:
        return JSONResponse(
            status_code=401,
            content={"error": {"code": exc.code, "message": exc.message, "detail": exc.detail}},
        )

    @app.exception_handler(AuthorizationError)
    async def authz_handler(_request: Request, exc: AuthorizationError) -> JSONResponse:
        return JSONResponse(
            status_code=403,
            content={"error": {"code": exc.code, "message": exc.message, "detail": exc.detail}},
        )

    @app.exception_handler(RateLimitExceededError)
    async def rate_limit_handler(_request: Request, exc: RateLimitExceededError) -> JSONResponse:
        return JSONResponse(
            status_code=429,
            content={"error": {"code": exc.code, "message": exc.message, "detail": exc.detail}},
        )

    @app.exception_handler(ValidationError)
    async def validation_handler(_request: Request, exc: ValidationError) -> JSONResponse:
        return JSONResponse(
            status_code=422,
            content={"error": {"code": exc.code, "message": exc.message, "detail": exc.detail}},
        )

    @app.exception_handler(PremiumRequiredError)
    async def premium_handler(_request: Request, exc: PremiumRequiredError) -> JSONResponse:
        return JSONResponse(
            status_code=402,
            content={"error": {"code": exc.code, "message": exc.message, "detail": exc.detail}},
        )

    @app.exception_handler(GeekyError)
    async def geeky_error_handler(_request: Request, exc: GeekyError) -> JSONResponse:
        logger.error("Unhandled domain error: %s", exc.message, exc_info=True)
        return JSONResponse(
            status_code=500,
            content={"error": {"code": exc.code, "message": exc.message, "detail": exc.detail}},
        )

    @app.exception_handler(Exception)
    async def unhandled_handler(_request: Request, exc: Exception) -> JSONResponse:
        logger.exception("Unhandled exception: %s", exc)
        return JSONResponse(
            status_code=500,
            content={"error": {"code": "INTERNAL_ERROR", "message": "An unexpected error occurred", "detail": None}},
        )


app = create_app()
