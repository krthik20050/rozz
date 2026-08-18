# ROZZ
### Your bank balance, finally understood.

ROZZ is a high-performance personal finance companion that bridges the gap between raw SMS alerts and actionable financial clarity. It autonomously parses HDFC bank notifications using a Node.js bridge, calculates Monthly Average Balance (MAB) in real-time, and employs an OpenRouter-powered AI (with Gemini free-tier fallback) to turn cryptic transaction narrations into meaningful categories.

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Next.js](https://img.shields.io/badge/next.js-000000?style=for-the-badge&logo=nextdotjs&logoColor=white)](https://nextjs.org)
[![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)

---

## 🚀 Key Features

- **Automated SMS Parsing:** Real-time extraction of transaction data from HDFC bank SMS via a native Dart parser (`features/transactions/data/datasources/sms_parser.dart`).
- **MAB Guardian:** Live tracking of Monthly Average Balance with "Safe/Danger" zones and predictive daily requirements to avoid bank fines.
- **AI Categorization:** Integrated OpenRouter AI API to automatically categorize transactions and provide financial insights.
- **Security First:** Biometric authentication and Android Keystore integration for sensitive data, with `FLAG_SECURE` protection.
- **Background Sync:** WorkManager-driven EOD balance snapshots and automated cloud synchronization.
- **Premium UI:** Dark-mode-only interface featuring Syne and DM Sans typography for a modern financial experience.

## 📂 Project Structure

```text
rozz_app/
├── lib/
│   ├── core/
│   │   ├── database/        # SQLite (WAL mode) & Write Queue
│   │   ├── security/        # Biometric & Keystore services
│   │   ├── services/        # Node.js Bridge, AI API, WorkManager
│   │   └── theme/           # Syne & DM Sans design tokens
│   ├── features/
│   │   ├── home/            # Summary & Hero widgets
│   │   ├── mab/             # MAB calculation & projection logic
│   │   └── transactions/    # SMS Parser & BLoC state management
│   └── shared/              # Reusable UI components
├── android/                 # SMS BroadcastReceiver & Native config
└── assets/                  # Branding & Design assets
```

## 🛠️ Setup & Installation

### Flutter App
1. **Clone the repository:**
   ```bash
   git clone https://github.com/krthik20050/rozz.git
   cd rozz/rozz_app
   ```
2. **Install dependencies:**
   ```bash
   flutter pub get
   ```
3. **Environment Setup:**
   - Create a `.env` file or update `SecureStorageService` with your `AI_API_KEY`.
4. **Run the app:**
   ```bash
   flutter run
   ```

### Next.js Backend (planned, not in this repo)
A Next.js + Supabase backend is referenced in the project docs but has not been scaffolded yet. This section will be filled in once it exists.

## 📸 Screenshots

> [!NOTE]
> *UI Preview placeholders. Real-time screenshots coming soon.*

| Home Dashboard | MAB Analytics | Transaction History |
| :---: | :---: | :---: |
| ![Home](https://via.placeholder.com/200x400?text=Home+UI) | ![MAB](https://via.placeholder.com/200x400?text=MAB+UI) | ![History](https://via.placeholder.com/200x400?text=History+UI) |

## 📈 Project Status
**Status:** `Actively in Development`
- [x] Phase 1: Premium UI & Architecture
- [x] Phase 2: Logic & Automation (SMS Parsing, MAB Engine, AI Sync) — 32/32 tests passing
- [ ] Phase 3: Cloud Sync & Insights (Next.js/Supabase backend not yet scaffolded)

## 👤 Author
**Karthik**
- GitHub: [@krthik20050](https://github.com/krthik20050)
- Project: ROZZ

---
*Built with precision for personal financial freedom.*
