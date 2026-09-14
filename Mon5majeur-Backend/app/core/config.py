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
    BACKEND_CORS_ORIGINS: list[str] | str = []

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
    SOCIAL_AUTH_GOOGLE_CLIENT_ID: str = (
        "144976760248-ncr727numc3pgi5nlq1fqp6t0k28gitv.apps.googleusercontent.com"
    )
    SOCIAL_AUTH_GOOGLE_SECRET: str = ""
    # Allowed Google Client IDs for Web, Android, and iOS clients
    GOOGLE_CLIENT_IDS: list[str] | str = [
        "144976760248-ncr727numc3pgi5nlq1fqp6t0k28gitv.apps.googleusercontent.com",  # Web / Server
        "144976760248-t1l00leat9g0jvace3f6chksju0nlc2n.apps.googleusercontent.com",  # Android
        "144976760248-m1k483v6kbi0o8i28l96b2pra777ppfk.apps.googleusercontent.com",  # iOS
    ]

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
    ALLOWED_UPLOAD_EXTENSIONS: list[str] | str = ["jpg", "jpeg", "png", "pdf", "docx"]
    # Absolute origin (e.g. "https://api.mon5majeur.com") the /static/... path
    # returned by an upload is prefixed with. The dashboard and mobile app are
    # served from a different origin than the API, so a bare "/static/..."
    # resolves against *their* origin and 404s — empty stays relative, for
    # local dev where everything shares one origin.
    PUBLIC_BASE_URL: str = ""

    @field_validator("PUBLIC_BASE_URL", mode="after")
    @classmethod
    def strip_trailing_slash(cls, v: str) -> str:
        return v.rstrip("/")

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

    @field_validator("GOOGLE_CLIENT_IDS", mode="before")
    @classmethod
    def split_google_client_ids(cls, v: str | list[str]) -> list[str]:
        if isinstance(v, str):
            return [i.strip() for i in v.split(",") if i.strip()]
        return v

    @property
    def allowed_google_client_ids(self) -> set[str]:
        ids: set[str] = set()
        if self.SOCIAL_AUTH_GOOGLE_CLIENT_ID:
            for cid in self.SOCIAL_AUTH_GOOGLE_CLIENT_ID.split(","):
                c = cid.strip()
                if c:
                    ids.add(c)
        if isinstance(self.GOOGLE_CLIENT_IDS, list):
            for cid in self.GOOGLE_CLIENT_IDS:
                c = str(cid).strip()
                if c:
                    ids.add(c)
        elif isinstance(self.GOOGLE_CLIENT_IDS, str):
            for cid in self.GOOGLE_CLIENT_IDS.split(","):
                c = cid.strip()
                if c:
                    ids.add(c)
        return ids

    # ── Pagination ────────────────────────────────────────────────────────────
    DEFAULT_PAGE_SIZE: int = 20
    MAX_PAGE_SIZE: int = 100


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
