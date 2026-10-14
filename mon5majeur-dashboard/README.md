# 💻 Mon5majeur — Admin Command Center

[![Next.js](https://img.shields.io/badge/Framework-Next.js%2015-000000?style=flat-square&logo=nextdotjs&logoColor=white)](https://nextjs.org)
[![React](https://img.shields.io/badge/UI-React%2019-61DAFB?style=flat-square&logo=react&logoColor=black)](https://react.dev)
[![TypeScript](https://img.shields.io/badge/Language-TypeScript%205-3178C6?style=flat-square&logo=typescript&logoColor=white)](https://www.typescriptlang.org)
[![Tailwind CSS](https://img.shields.io/badge/Styling-Tailwind%20CSS%20v4-38B2AC?style=flat-square&logo=tailwind-css&logoColor=white)](https://tailwindcss.com)

The official administrative portal for the **Mon5majeur** fantasy basketball ecosystem. Provides comprehensive management over users, leagues, real-time match scores, booster cards, and platform analytics.

---

## 🚀 Key Modules

- **User Management (`/adminDashboard/userManagement`)**: View registered users, account status, avatar review, verification management, and account bans.
- **League Moderation (`/adminDashboard/leagueManagement`)**: Monitor public pools and private leagues, view participant counts, inspect standings, and manage playoff brackets.
- **Match & Score Management (`/adminDashboard/match&scoreManagement`)**: Real-time match monitoring, live score feeds, manual stat overrides, and Goalserve sync inspection.
- **Bonus & Store Management (`/adminDashboard/bonus&storeManagement`)**: Configure booster cards catalog, adjust token pricing, and audit in-app purchases.
- **Analytics & Reporting (`/adminDashboard/analytics&reporting`)**: Visual dashboards showing user growth, active matchday engagement, token transactions, and platform health (using **Chart.js** & **Recharts**).
- **Security & Compliance (`/adminDashboard/security&compliance`)**: Granular role-based access management and audit trails.

---

## 📂 Project Structure

```
mon5majeur-dashboard/
├── src/
│   ├── app/
│   │   ├── adminDashboard/         # Administrative module sub-routes
│   │   │   ├── analytics&reporting/
│   │   │   ├── bonus&storeManagement/
│   │   │   ├── leagueManagement/
│   │   │   ├── match&scoreManagement/
│   │   │   ├── security&compliance/
│   │   │   ├── settings/
│   │   │   └── userManagement/
│   │   ├── forgetPassword/         # Password recovery screens
│   │   ├── singin/                 # Admin authentication screen
│   │   ├── globals.css             # Tailwind CSS tokens & base styles
│   │   └── layout.tsx              # Root HTML layout & toast providers
│   └── components/                 # Reusable cards, charts, modals, sidebars
├── package.json
└── tsconfig.json
```

---

## 🛠 Getting Started

### Prerequisites
- Node.js 18.x or 20.x
- npm or pnpm

### Setup
```bash
# 1. Install dependencies
npm install

# 2. Configure environment
cp .env.example .env.local

# 3. Set the Backend API URL in .env.local
# NEXT_PUBLIC_API_URL=http://localhost:8000/api

# 4. Start development server
npm run dev
```

Visit **[http://localhost:3000](http://localhost:3000)** to access the dashboard.

---

## 🧪 Linting & Production Build

```bash
# Run ESLint
npm run lint

# Build for production
npm run build

# Start production server
npm run start
```
