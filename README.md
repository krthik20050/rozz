# ROZZ

### Your bank balance, finally understood.

ROZZ is a privacy-first personal finance app for Android (Flutter). It turns your
HDFC bank SMS into a living picture of your money: every transaction parsed and
categorized, Monthly Average Balance (MAB) tracked against the ₹10,000 minimum to
avoid bank fines, subscriptions and recurring income detected from your own
history, and a ChatGPT-style AI assistant that answers any question about your
money from your full on-device record.

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://www.android.com)

---

## ✨ Features

- **Live SMS capture** — HDFC bank alerts arrive via Android notification
  listener (foreground service) and SMS receiver; a Kotlin JSONL handoff feeds
  a robust native Dart parser. On Android 13+ you can make ROZZ the default SMS
  handler to backfill full history.
- **Transaction ledger** — every debit/credit parsed into amount, direction,
  recipient, optional balance-after, category, and the original SMS.
- **MAB Guardian** — real-time Monthly Average Balance vs the ₹10,000 threshold,
  with safe / middle / danger / fine zones, a forecast, and an estimated penalty.
- **Insights** — monthly summary, money-in by sender, recurring income,
  subscriptions (detected locally from your own history, dismissible false
  positives), and upcoming charges.
- **AI assistant (chat)** — ChatGPT-style streaming chat. It reads your **full
  local record** and answers in clean markdown with tables. Model: GROQ
  `openai/gpt-oss-120b` (free); OpenRouter and Gemini free-tier keys also work.
- **Background sync** — WorkManager keeps EOD balance snapshots and drains
  pending SMS even when the app is closed.
- **Premium dark UI** — Syne / DM Sans / DM Mono, skeletons and empty/error
  states everywhere.

## 🔒 Security

- **On-device by default.** Your transactions, balances and SMS never leave the
  phone except for AI requests, and those are scrubbed first.
- **PII redaction** — UPI ids, phone numbers, reference numbers and balances are
  replaced before anything is sent to the AI provider.
- **Keystore-backed keys** — the AI API key lives in Android Keystore via
  `flutter_secure_storage`; it is never written into code or logs. A dev seed is
  injected at build time with `--dart-define=GROQ_API_KEY=…` and can be cleared
  in Settings.
- **AI routing** — keys are auto-routed by prefix: `gsk_…` → GROQ,
  `sk-or-…` → OpenRouter, `AIza…` → Gemini. Never log the key.
- **Honest gaps (on the roadmap)** — database at rest is currently unencrypted;
  SMS and screenshot protection hardening is in progress. See
  `docs/daily-log/2026-08-19.md`.

## 🧱 How it works

1. **Capture** — notification listener / receiver grabs HDFC bank SMS (raw SMS
   stored on-device, redacted at the network boundary).
2. **Parse** — `SmsParser` turns each message into a transaction or an EOD
   balance snapshot.
3. **Route & dedupe** — balance snapshots land in `mab_history` (source of truth
   for current balance); transactions land in the ledger with a dedupe key.
4. **Compute** — MAB, streaks, subscriptions, recurring income and insights are
   computed from your own data — never hardcoded.
5. **Ask** — the chat builds a context from the full ledger + summaries, sends it
   (redacted) to the AI, and streams the answer back in markdown.

## 🗂 Project structure

```text
rozz_app/
├── lib/
│   ├── core/
│   │   ├── database/          # SQLite (WAL) + write queue + migrations
│   │   ├── security/          # Keystore-backed secure storage
│   │   ├── services/          # AiService (GROQ/OpenRouter/Gemini), SMS sync, WorkManager
│   │   └── theme/             # RozzColors + typography tokens
│   ├── features/
│   │   ├── chat/              # AI chat (streaming, markdown, full-record context)
│   │   ├── home/              # Dashboard + balance hero
│   │   ├── mab/               # MAB engine, forecast, fine estimate
│   │   ├── insights/          # Summary, income, subscriptions, upcoming charges
│   │   ├── transactions/      # SMS parser, repository, BLoC
│   │   └── onboarding/        # Setup, key entry, settings
│   ├── shared/                # Reusable widgets & utils (merchant brand, sender labels)
│   └── main.dart              # Composition root (injections, key bootstrap)
├── android/                   # Kotlin SMS capture, notification listener, manifest
├── assets/                    # mock_sms.json (test/fake data), icons
├── docs/                      # daily log, plans, specs, research
└── test/                      # 119 tests (parsers, blocs, usecases, services)
```

## 🛠️ Setup & run

```bash
cd rozz_app
flutter pub get

# Dev (Android device/emulator; desktop works for UI dev)
flutter run

# Release build with the GROQ dev key baked in (or set the key in-app later)
flutter build apk --release --dart-define=GROQ_API_KEY=gsk_…
adb install -r build/app/outputs/flutter-apk/app-release.apk

# Quality gates
flutter analyze      # must be clean
flutter test         # 119 tests, keep green
```

**AI keys** — the app needs a key to answer chat questions. Get a free GROQ key
at [console.groq.com](https://console.groq.com) (`gsk_…`). Paste it in the chat's
setup screen or in Settings; it stays on your phone.

## 🗺 Status & roadmap

- [x] **Phase 1** — scaffold, premium UI, navigation.
- [x] **Phase 2** — SQLite, SMS capture + parser, WorkManager sync, GROQ AI,
      MAB engine, insights, subscriptions, PII redaction, ChatGPT-style chat.
- [ ] **Security hardening** — SMS-parsing safety, manifest hardening
      (`FLAG_SECURE`, `allowBackup`, exported components), DB-at-rest encryption.
- [ ] **App lock / biometric** — re-enable (was stubbed).
- [ ] **Backend** — a Next.js + Supabase cloud sync is referenced in the docs
      but **not part of this repo**.

## 📚 Docs

- `docs/daily-log/` — what changed, day by day.
- `docs/superpowers/plans/` & `specs/` — feature plans and designs.
- `docs/research/` — design/UX research notes.
- `AGENTS.md` — the project brain file (domain language, architecture rules).
- `CONTEXT.md` — domain language glossary.

## 👤 Author

**Karthik** — [@krthik20050](https://github.com/krthik20050)

---

*Built with precision for personal financial freedom.*