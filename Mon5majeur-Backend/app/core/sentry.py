"""
Sentry error monitoring (spec §5.3 — server-side blind-spot safety net).
No-op if SENTRY_DSN is unset or the package isn't installed yet, so this
never blocks startup before the dependency/DSN are actually provisioned.
"""
from __future__ import annotations

import logging

from app.core.config import settings

logger = logging.getLogger(__name__)


def init_sentry() -> None:
    if not settings.SENTRY_DSN:
        logger.info("Sentry disabled (SENTRY_DSN not set)")
        return

    try:
        import sentry_sdk
    except ImportError:
        logger.warning("SENTRY_DSN is set but sentry-sdk isn't installed — run `pip install -r requirements.txt`")
        return

    sentry_sdk.init(
        dsn=settings.SENTRY_DSN,
        environment=settings.ENVIRONMENT,
        traces_sample_rate=settings.SENTRY_TRACES_SAMPLE_RATE,
    )
    logger.info("Sentry initialized (environment=%s)", settings.ENVIRONMENT)
