from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import AnyHttpUrl, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

# app/core/config.py -> app/core -> app -> project root. A relative
# UPLOAD_DIR must not depend on the process's working directory: gunicorn/
# systemd can launch uvicorn from a different cwd than a plain `python -m`
# run does, silently pointing uploads at (and creating) the wrong directory
# — one that may not be writable, which is exactly what a 500 on every
# upload while everything else works looks like.
_PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", case_sensitive=False, extra="ignore")

    # ── App ──────────────────────────────────────────────────────────────────
    APP_NAME: str = "Mon5majeur API"
    APP_VERSION: str = "1.0.0"
    API_V1_PREFIX: str = "/api/v1"
    DEBUG: bool = False
    ENVIRONMENT: Literal["development", "staging", "production"] = "development"

    # ── Security / JWT ────────────────────────────────────────────────────────
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # ── MongoDB ───────────────────────────────────────────────────────────────
    MONGODB_URI: str = "mongodb://localhost:27017"
    MONGODB_DB_NAME: str = "mon5majeur_db"

    # ── Redis ─────────────────────────────────────────────────────────────────
    REDIS_HOST: str = "localhost"
    REDIS_PORT: int = 6379
    REDIS_URL: str = "redis://localhost:6379/0"

    # ── CORS ─────────────────────────────────────────────────────────────────
    BACKEND_CORS_ORIGINS: list[str] = []

    @field_validator("DEBUG", mode="before")
    @classmethod
    def parse_debug_value(cls, value):
        if isinstance(value, bool):
            return value
        if isinstance(value, str):
            normalized = value.strip().lower()
            if normalized in {"true", "1", "yes", "on", "development", "dev"}:
                return True
            if normalized in {"false", "0", "no", "off", "release", "production", "prod"}:
                return False
        return value

    @field_validator("BACKEND_CORS_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: str | list[str]) -> list[str]:
        if isinstance(v, str):
            return [i.strip() for i in v.split(",")]
        return v

    # ── AWS S3 ────────────────────────────────────────────────────────────────
    AWS_ACCESS_KEY_ID: str = ""
    AWS_SECRET_ACCESS_KEY: str = ""
    AWS_STORAGE_BUCKET_NAME: str = ""
    AWS_S3_REGION_NAME: str = "eu-north-1"
    AWS_S3_SIGNATURE_VERSION: str = "s3v4"

    # ── Google OAuth ──────────────────────────────────────────────────────────
    SOCIAL_AUTH_GOOGLE_CLIENT_ID: str = ""
    SOCIAL_AUTH_GOOGLE_SECRET: str = ""

    # ── Apple OAuth ───────────────────────────────────────────────────────────
    APPLE_CLIENT_ID: str = ""
    APPLE_KEY_ID: str = ""
    APPLE_TEAM_ID: str = ""
    APPLE_CERTIFICATE_KEY: str = ""
    APPLE_CLIENT_SECRET: str = ""

    # ── Goalserve ─────────────────────────────────────────────────────────────
    GOALSERVE_API_KEY: str = ""

    # ── Scheduler ────────────────────────────────────────────────────────────
    ENABLE_SCHEDULER: bool = True          # set False in tests/workers that don't run CRON

    # ── FCM (Firebase Cloud Messaging) ───────────────────────────────────────
    FCM_CREDENTIALS_PATH: str = ""         # path to serviceAccountKey.json

    # ── Sentry (error monitoring — spec §5.3) ────────────────────────────────
    SENTRY_DSN: str = ""                   # empty = disabled
    SENTRY_TRACES_SAMPLE_RATE: float = 0.1

    # ── Email ─────────────────────────────────────────────────────────────────
    SMTP_HOST: str = ""
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    EMAILS_FROM_EMAIL: str = "noreply@mon5majeur.com"
    EMAILS_FROM_NAME: str = "Mon5majeur"

    # ── File Upload ───────────────────────────────────────────────────────────
    UPLOAD_DIR: str = "uploads"
    MAX_UPLOAD_SIZE_MB: int = 10
    ALLOWED_UPLOAD_EXTENSIONS: list[str] = ["jpg", "jpeg", "png", "pdf", "docx"]

    @field_validator("UPLOAD_DIR", mode="after")
    @classmethod
    def resolve_upload_dir(cls, v: str) -> str:
        """A relative path is anchored to the project root, not whatever the
        process's cwd happens to be — see _PROJECT_ROOT above. An operator
        who sets an absolute UPLOAD_DIR in .env (e.g. a mounted volume) is
        left untouched."""
        p = Path(v)
        return str(p if p.is_absolute() else _PROJECT_ROOT / p)

    @field_validator("ALLOWED_UPLOAD_EXTENSIONS", mode="before")
    @classmethod
    def split_extensions(cls, v: str | list[str]) -> list[str]:
        if isinstance(v, str):
            return [i.strip() for i in v.split(",")]
        return v

    # ── Pagination ────────────────────────────────────────────────────────────
    DEFAULT_PAGE_SIZE: int = 20
    MAX_PAGE_SIZE: int = 100


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
