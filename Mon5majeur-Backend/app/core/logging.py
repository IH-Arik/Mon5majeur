import logging
import sys
from typing import Any

from app.core.config import settings

LOG_FORMAT = "%(asctime)s | %(levelname)-8s | %(name)s:%(lineno)d - %(message)s"
DATE_FORMAT = "%Y-%m-%dT%H:%M:%S"


def configure_logging() -> None:
    level = logging.DEBUG if settings.DEBUG else logging.INFO

    logging.basicConfig(
        level=level,
        format=LOG_FORMAT,
        datefmt=DATE_FORMAT,
        handlers=[logging.StreamHandler(sys.stdout)],
    )

    # httpx logs every request URL at INFO, and the Goalserve feed URL carries
    # the API key: never let it reach the logs, whatever the log level.
    for leaky in ("httpx", "httpcore"):
        logging.getLogger(leaky).setLevel(logging.WARNING)

    # Silence noisy third-party loggers in production
    if not settings.DEBUG:
        for noisy in ("uvicorn.access", "sqlalchemy.engine"):
            logging.getLogger(noisy).setLevel(logging.WARNING)


def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(name)
