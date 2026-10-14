FROM python:3.12-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# ── Dependencies ─────────────────────────────────────────────────────────────
FROM base AS deps
COPY requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt

# ── Final image ───────────────────────────────────────────────────────────────
FROM deps AS final
COPY . .

RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

# The Firebase key is bind-mounted into /app/secrets (docker-compose.prod.yml).
# If the folder is not in the image, Docker creates it at every container
# recreate as root:root 0700, appuser cannot reach the key and every push
# silently fails (QA #13 item 8). Create it readable by the app user.
RUN mkdir -p /app/secrets && chown appuser:appgroup /app/secrets && chmod 755 /app/secrets

USER appuser

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
