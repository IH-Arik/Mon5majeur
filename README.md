# 🏀 Mon5majeur — Monorepo

[![Built with FastAPI](https://img.shields.io/badge/Backend-FastAPI-009688.svg?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Built with Next.js](https://img.shields.io/badge/Frontend-Next.js-000000.svg?style=for-the-badge&logo=nextdotjs&logoColor=white)](https://nextjs.org)
[![Built with Flutter](https://img.shields.io/badge/Mobile-Flutter-02569B.svg?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Database MongoDB](https://img.shields.io/badge/Database-MongoDB-47A248.svg?style=for-the-badge&logo=mongodb&logoColor=white)](https://www.mongodb.com)

**Mon5majeur** (French for *My Starting Five*) is a next-generation fantasy basketball/sports application. Users can build their starting five lineups, participate in public and private leagues, compete with friends, buy tokens, activate booster cards, and track live scores in real-time.

This repository is organized as a unified monorepo containing the backend API, landing page, administrative dashboard, and the mobile application.

---

## 📂 Repository Structure

```
Mon5majeur/
├── Mon5majeur-Backend/        # FastAPI backend service (Python 3.12, Beanie/MongoDB)
├── Mon5majeur-landing page/   # Marketing & subscriber registration (Next.js JS)
├── mon5majeur-dashboard/      # Administrator & analytics dashboard (Next.js TS)
└── mon5majeur_app-main/       # Mobile client application (Flutter / Dart)
```

---

## 🚀 Quick Start & Installation

### 1. Mon5majeur-Backend (API)
A fast, asynchronous Python API powered by FastAPI and Beanie ODM for MongoDB.

* **Prerequisites**: Python 3.12+, MongoDB, Redis (optional)
* **Setup**:
  ```bash
  cd Mon5majeur-Backend
  python -m venv venv
  source venv/Scripts/activate # On Windows: venv\Scripts\activate
  pip install -r requirements.txt
  ```
* **Configuration**:
  Copy `.env.example` to `.env` and configure your MongoDB connection (Atlas or local), JWT keys, FCM keys, and external APIs:
  ```bash
  cp .env.example .env
  ```
* **Running Locally**:
  ```bash
  uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
  ```
* **Running via Docker**:
  ```bash
  docker-compose up --build
  ```

---

### 2. mon5majeur-dashboard (Admin Web Portal)
An interactive next-generation dashboard built with Next.js (TypeScript) and TailwindCSS.

* **Prerequisites**: Node.js 18+
* **Setup & Run**:
  ```bash
  cd mon5majeur-dashboard
  npm install
  # Copy .env.example and configure NEXT_PUBLIC_API_URL
  cp .env.example .env.local
  npm run dev
  ```
* Access the web dashboard at `http://localhost:3000`.

---

### 3. Mon5majeur-landing page (Public Website)
A high-converting marketing landing page integrated with Mailerlite for subscriber capture.

* **Prerequisites**: Node.js 18+
* **Setup & Run**:
  ```bash
  cd "Mon5majeur-landing page"
  npm install
  # Copy .env.example and configure Mailerlite API keys
  cp .env.example .env.local
  npm run dev
  ```
* Access the landing page at `http://localhost:3001`.

---

### 4. mon5majeur_app-main (Flutter Mobile App)
Cross-platform iOS and Android mobile app providing a fluid, native fantasy sports experience.

* **Prerequisites**: Flutter SDK (3.10.x+), Android Studio / Xcode
* **Setup**:
  ```bash
  cd mon5majeur_app-main
  flutter pub get
  ```
* **API Configuration**:
  Modify the backend endpoint URL in [api_url.dart](file:///c:/Users/ittes/Desktop/Arik/Desktop/ARIK/Mon5majeur/mon5majeur_app-main/lib/data/services/api_url.dart):
  ```dart
  static const baseUrl = "YOUR_BACKEND_API_URL"; // e.g. https://api.mon5majeur.com or ngrok tunnel
  ```
* **Run in Emulator**:
  ```bash
  flutter run
  ```

---

## 🛠 Production Deployment

### Docker Deployment (API Backend)
To deploy the backend to production using Docker Compose (which runs the API container, an optional MongoDB instance, and Nginx reverse proxy):

1. Create a `.env.prod` environment configuration file in `Mon5majeur-Backend/`.
2. Launch the orchestration stack:
   ```bash
   cd Mon5majeur-Backend
   docker-compose -f docker-compose.prod.yml up -d --build
   ```

### Vercel / Netlify Deployment (Landing & Dashboard)
Both frontends are fully optimized for hosting on Vercel or similar static hosting providers. Add the respective project directory root and environment variables (`NEXT_PUBLIC_API_URL`, `MAILERLITE_API_KEY`) to your hosting provider's build configurations.

---

## 📝 Documentations

* **Deep Architecture and Feature Description**: See [DESCRIPTION.md](file:///c:/Users/ittes/Desktop/Arik/Desktop/ARIK/Mon5majeur/DESCRIPTION.md) for detailed descriptions of models, features, API design patterns, and league rules.
