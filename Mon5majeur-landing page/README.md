# 🌐 Mon5majeur — Marketing Landing Page

[![Next.js](https://img.shields.io/badge/Framework-Next.js%2016-000000?style=flat-square&logo=nextdotjs&logoColor=white)](https://nextjs.org)
[![React](https://img.shields.io/badge/UI-React%2019-61DAFB?style=flat-square&logo=react&logoColor=black)](https://react.dev)
[![Tailwind CSS](https://img.shields.io/badge/Styling-Tailwind%20CSS%20v4-38B2AC?style=flat-square&logo=tailwind-css&logoColor=white)](https://tailwindcss.com)
[![Motion](https://img.shields.io/badge/Animation-Framer%20Motion-FF0055?style=flat-square)](https://motion.dev)
[![i18n](https://img.shields.io/badge/Localization-next--intl%20%2F%20i18next-brightgreen?style=flat-square)](https://next-intl-docs.vercel.app)

The official public landing page for **Mon5majeur**. Designed for high conversion, user onboarding, and newsletter lead capture.

---

## 🚀 Key Features

- **High-Performance UI**: Built on **Next.js 16** with Tailwind CSS v4 and fluid animations via **Framer Motion** (`motion/react`) and **AOS**.
- **Internationalization (i18n)**: Multi-language support catering to international basketball audiences using `next-intl` and `i18next`.
- **Lead Generation**: Integrated subscriber registration with **MailerLite** for early-bird waitlists and marketing campaigns.
- **Responsive Design**: Mobile-first layouts optimized for smartphone browsers and social sharing cards.

---

## 📂 Project Structure

```
Mon5majeur-landing page/
├── src/
│   ├── app/
│   │   ├── api/             # API routes (MailerLite newsletter integration)
│   │   ├── contact/         # Contact us screen
│   │   ├── privacy/         # Privacy Policy page
│   │   ├── terms/           # Terms & Conditions page
│   │   ├── layout.js        # Root HTML layout and metadata
│   │   └── page.jsx         # Main conversion landing page
│   └── components/          # Hero, Features, Testimonials, FAQ, Footer
├── public/                  # Static assets & OpenGraph images
└── package.json
```

---

## 🛠 Getting Started

### Prerequisites
- Node.js 18.x or 20.x
- npm, pnpm, or yarn

### Setup & Run
```bash
# 1. Install dependencies
npm install

# 2. Configure environment
cp .env.example .env.local

# 3. Start development server on port 3001
npm run dev -- -p 3001
```

Visit **[http://localhost:3001](http://localhost:3001)** to preview the site.

---

## 🧪 Build & Linting

```bash
# Run linting
npm run lint

# Compile production bundle
npm run build

# Start production server
npm run start
```
