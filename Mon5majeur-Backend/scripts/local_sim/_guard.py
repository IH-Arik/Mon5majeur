"""Safety rails of the local simulator: it only ever runs against a local
database named m5m_local_*, with every outside service switched off."""
from __future__ import annotations

import sys

LOCAL_HOSTS = {"localhost", "127.0.0.1", "::1"}
DB_PREFIX = "m5m_local_"


def fail(message: str) -> None:
    print(f"\nREFUSED: {message}\nNothing was started, read or written.", file=sys.stderr)
    raise SystemExit(2)


def check_settings(settings) -> None:
    """`settings` is what the application would REALLY use (environment, then any
    .env), not what was typed."""
    from pymongo.uri_parser import parse_uri

    uri = settings.MONGODB_URI or ""
    if not uri or uri.startswith("mongodb+srv"):
        fail("the database connection string is empty or a remote (mongodb+srv) cluster")
    try:
        hosts = [h for h, _ in parse_uri(uri)["nodelist"]]
    except Exception as exc:  # noqa: BLE001
        fail(f"cannot read the connection string ({exc.__class__.__name__})")
    remote = [h for h in hosts if h not in LOCAL_HOSTS]
    if remote or not hosts:
        fail(f"the database is not on this machine: {remote or 'no host'}")
    if not settings.MONGODB_DB_NAME.startswith(DB_PREFIX):
        fail(f"the database name must start with '{DB_PREFIX}' (got '{settings.MONGODB_DB_NAME}')")
    if settings.ENVIRONMENT == "production":
        fail("ENVIRONMENT is 'production'")
    outside = [name for name in ("SMTP_HOST", "FCM_CREDENTIALS_PATH", "GOALSERVE_API_KEY", "SENTRY_DSN")
               if getattr(settings, name, "")]
    if outside:
        fail("these outside services are configured and must be empty here: " + ", ".join(outside))
    if settings.ENABLE_SCHEDULER:
        fail("ENABLE_SCHEDULER must be false (no cron job, no feed polling)")
