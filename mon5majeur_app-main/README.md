# 📱 Mon5majeur — Mobile Client (Flutter)

[![Flutter](https://img.shields.io/badge/Platform-Flutter%203.10%2B-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Language-Dart%203-0175C2?style=flat-square&logo=dart&logoColor=white)](https://dart.dev)
[![iOS](https://img.shields.io/badge/OS-iOS-000000?style=flat-square&logo=apple&logoColor=white)](https://apple.com)
[![Android](https://img.shields.io/badge/OS-Android-3DDC84?style=flat-square&logo=android&logoColor=white)](https://android.com)
[![State](https://img.shields.io/badge/State-GetX-800080?style=flat-square)](https://pub.dev/packages/get)
[![In-App Purchases](https://img.shields.io/badge/IAP-RevenueCat-E74C3C?style=flat-square)](https://www.revenuecat.com)

The flagship mobile application for **Mon5majeur**, providing basketball fans with a fluid, native fantasy sports experience on iOS and Android.

---

## ✨ Features

- **Starting Five Lineup Builder**: Intuitive visual court where users draft 5 starters matching real-world basketball positions (PG, SG, SF, PF, C) within salary credit limits.
- **Real-Time Live Scoring**: WebSocket-powered live score ticker updating points, assists, rebounds, blocks, and fantasy calculations in real time.
- **League Competition**:
  - Join public competitive pools.
  - Create private leagues with room passcodes and shareable invite links.
  - Head-to-head matchday showdowns and knockout playoff brackets.
- **Token Economy & In-App Purchases**: In-app token wallet powered by **RevenueCat** for buying booster cards (e.g. Captain 2x multipliers).
- **Social & Fast Authentication**: Seamless login via Google OAuth, Sign in with Apple, or Email OTP verification.
- **Push Alerts**: Instant Firebase Cloud Messaging notifications for roster lock countdowns and match outcomes.

---

## 📂 Architecture

The application adopts Clean Architecture principles with **GetX** for dependency injection and state management:

```
mon5majeur_app-main/
├── lib/
│   ├── controllers/      # GetX state & business logic controllers
│   ├── core/             # Base themes, HTTP client, constants, network checkers
│   ├── data/             # Remote API services, data providers, models
│   ├── presentation/     # UI Layer:
│   │   ├── authentication/ # Login, Register, OTP, Forgot Password
│   │   ├── home/           # Dashboard, live scores, upcoming matches
│   │   ├── mymatch/        # Lineup builder, league fixtures, head-to-head
│   │   ├── profile/        # User profile, wallet balance, settings
│   │   ├── shop/           # In-app token store and booster cards
│   │   └── tutorial/       # Interactive walkthrough for new players
│   ├── utils/            # UI formatters, responsive ScreenUtil adapters
│   ├── firebase_options.dart # Firebase client options
│   └── main.dart         # App entrypoint
├── assets/               # Vector icons, team logos, audio, animations
└── pubspec.yaml          # Dependencies & build configuration
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`v3.10.x` or higher)
- Android Studio / Xcode configured with emulators or physical test devices

### Installation & Launch

```bash
# 1. Fetch dependencies
flutter pub get

# 2. Configure Backend API Endpoint
# Edit lib/data/services/api_url.dart to point to your local or deployed backend:
# - Android Emulator: http://10.0.2.2:8000/api
# - iOS Simulator:    http://localhost:8000/api
# - Staging/Prod:     https://api.mon5majeur.com/api

# 3. Run on connected device
flutter run
```

---

## 🧪 Testing & Linting

```bash
# Run unit & widget tests
flutter test

# Run code analysis
flutter analyze
```

---

## 📦 Building Release Binaries

```bash
# Android APK
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS (Xcode archive)
flutter build ipa --release
```
