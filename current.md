# ROZZ — Project Progress

> Keep this file current. Updated last: 2026-08-19.
> Daily work log lives in `docs/daily-log/`.

## Phase 1 — App scaffold & UI (COMPLETE)

- [x] Feature-first architecture (`lib/features/<feature>/{data,domain,presentation}`).
- [x] Onboarding, Home, Transactions, MAB, Insights, Sync, Settings screens.
- [x] Skeleton loaders, empty & error states everywhere.
- [x] Dark premium UI (`#080810`), Syne / DM Sans / DM Mono design tokens.

## Phase 2 — Logic & Automation (MOSTLY COMPLETE)

- [x] SQLite (sqflite) with WAL mode + write queue + migrations (in-app DB v8).
- [x] Robust HDFC SMS parser (50 mock edge cases covered).
- [x] Native SMS capture: notification-listener foreground service + receiver,
      Kotlin JSONL handoff, default-SMS-handler backfill (Android 13+).
- [x] WorkManager EOD balance snapshots + background SMS drain (6h).
- [x] AI integration: **GROQ** primary (`gsk_` keys; `openai/gpt-oss-120b` chat,
      `groq/compound-mini` categorize), OpenRouter `openrouter/free` + Gemini
      `gemini-flash-lite-latest` fallbacks, auto-routed by key prefix.
- [x] MAB engine (threshold ₹10,000, zones, forecast, fine estimate, streak).
- [x] Insights: monthly summary, income sources, recurring income,
      subscriptions (local detection + dismiss), upcoming charges.
- [x] Secure key storage (Android Keystore via flutter_secure_storage);
      PII redaction (UPI ids, phones, refs, balances) before anything leaves
      the device.

## Today (2026-08-19) — ChatGPT-style AI chat

- [x] Streaming answers (SSE) with blinking caret + stop button.
- [x] Assistant replies render as rich markdown incl. tables; copy button.
- [x] Suggestion chips + greeting on empty state; centered chat column.
- [x] System prompt: guardrails removed, replaced by formatting rules
      (no em dashes, no star bullets, prefer tables).
- [x] Chat now sends the FULL transaction ledger + month summary + MAB, no
      intent gate. PII redaction unchanged.
- [x] 119 tests passing, analyze clean, release APK built (not yet installed).

## Open tasks

- [ ] Security hardening audit + stress test (see `docs/daily-log/2026-08-19.md`).
- [ ] DB-at-rest encryption (re-do the reverted sqflite_sqlcipher work properly).
- [ ] Install latest APK on device (phone wasn't connected).
- [ ] App lock / biometric re-enable (stubbed earlier — TODO).
- [ ] Home → transaction-detail navigation (TODO).
- [ ] Next.js + Supabase backend — referenced in docs, NOT in this repo.