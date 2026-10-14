# ⚡ Mon5majeur — Backend Service

[![FastAPI](https://img.shields.io/badge/Framework-FastAPI%200.115-009688?style=flat-square&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=flat-square&logo=python&logoColor=white)](https://python.org)
[![MongoDB](https://img.shields.io/badge/Database-MongoDB%20%2B%20Beanie-47A248?style=flat-square&logo=mongodb&logoColor=white)](https://www.mongodb.com)
[![Docker](https://img.shields.io/badge/Container-Docker-2496ED?style=flat-square&logo=docker&logoColor=white)](https://www.docker.com)
[![Sentry](https://img.shields.io/badge/Observability-Sentry-362D59?style=flat-square&logo=sentry&logoColor=white)](https://sentry.io)

Asynchronous core REST API and WebSocket engine powering the **Mon5majeur** fantasy basketball platform. Built with **FastAPI**, **Motor / Beanie ODM**, and **APScheduler**.

---

## 🛠 Features

- **Asynchronous Architecture**: High-performance async I/O handling high concurrency during game days.
- **Real-Time WebSockets**: Live score distribution and fantasy point recalculations streamed to mobile clients.
- **Automated Data Ingestion**: Background cron scheduler pulling live rosters, match schedules, and real-time player statistics from the **Goalserve Sports API**.
- **Auth & Access Control**: Email verification via OTP, social logins (Google OAuth & Apple Sign-In), JWT bearer tokens, and granular Role-Based Access Control (RBAC).
- **Fantasy Game Engine**:
  - Validation for 5-player starting rosters with positional constraints and credit caps.
  - Public match pools and private leagues with passcode security.
  - Automated tournament round-robin matches and knockout playoff brackets.
  - Virtual `TokenWallet` ledger and booster cards store.
- **Cloud Integrations**:
  - **AWS S3**: Cloud storage for avatars and media uploads.
  - **Firebase Cloud Messaging (FCM)**: Push notification dispatch for matchday reminders and league events.
  - **Sentry.io**: Centralized exception tracking and performance tracing.

---

## 📂 Architecture & Directory Structure

```
Mon5majeur-Backend/
├── app/
│   ├── api/                  # Unified API router mounting all domain modules
│   ├── core/                 # App configuration, security settings, JWT tokens
│   ├── cron/                 # APScheduler tasks (Goalserve sports ingestion)
│   ├── database/             # MongoDB connection setup & Beanie ODM initialization
│   ├── exceptions/           # Custom domain exceptions and HTTP error handlers
│   ├── middleware/           # CORS, timing, and security middlewares
│   ├── modules/              # Domain-Driven Design (DDD) feature modules:
│   │   ├── analytics/        # Match and platform performance metrics
│   │   ├── auth/             # Login, signup, OTP, Google/Apple OAuth
│   │   ├── bonuses/          # Booster cards & user quotas
│   │   ├── competitions/     # Match fixtures and matchday calendars
│   │   ├── files/            # S3 uploads and asset handlers
│   │   ├── leagues/          # Public & private league lifecycle + playoffs
│   │   ├── lineups/          # Starting 5 selection & budget cap validator
│   │   ├── live_scores/      # Real-time WebSocket handlers & scoring
│   │   ├── notifications/    # Firebase FCM push notifications
│   │   ├── players/          # Basketball athletes, credit values, stats
│   │   ├── roles/            # RBAC role & permission models
│   │   ├── tokens/           # In-app token transactions & wallet
│   │   └── users/            # User profile management & preferences
│   ├── shared/               # Shared Pydantic schemas and models
│   └── utils/                # Date/time, cryptographic and mathematical utilities
├── docker/                   # Nginx reverse proxy configuration
├── tests/                    # Pytest test suite
├── Dockerfile                # Production container specification
├── docker-compose.yml        # Development multi-container orchestration
├── docker-compose.prod.yml   # Production orchestration stack
├── Makefile                  # Developer workflow targets
├── requirements.txt          # Production dependencies
└── requirements-dev.txt      # Testing and development tooling
```

---

## 🚀 Getting Started

### Prerequisites
- Python 3.12+
- MongoDB 6.0+ (Local or Atlas)
- Redis (Optional, for caching)

### Local Setup
```bash
# 1. Create and activate virtual environment
python -m venv venv

# On Windows:
.\venv\Scripts\Activate.ps1
# On macOS/Linux:
source venv/bin/activate

# 2. Install dependencies
pip install -r requirements.txt
pip install -r requirements-dev.txt

# 3. Configure environment
cp .env.example .env
# Fill in your MONGODB_URI, SECRET_KEY, and external API keys

# 4. Start local development server
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

* Interactive Swagger Docs: **[http://localhost:8000/docs](http://localhost:8000/docs)**
* ReDoc Specification: **[http://localhost:8000/redoc](http://localhost:8000/redoc)**

---

## 🧪 Testing & Code Quality

```bash
# Run tests with coverage
pytest tests/ -v --cov=app

# Run linting
ruff check .

# Auto-fix linting issues
ruff check . --fix

# Type validation
mypy app --ignore-missing-imports
```

---

## 🐳 Docker Deployment

```bash
# Run with local Docker Compose (API + Mongo)
docker compose up -d --build

# Run in production mode with Nginx reverse proxy
docker compose -f docker-compose.prod.yml up -d --build
```
