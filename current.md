# ROZZ — Project Progress

> Keep this file current. Updated last: 2026-08-20.
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

## Security hardening (2026-08-19)

- [x] **DB-at-rest encryption (SQLCipher)** — `sqflite_sqlcipher` wired into
      `DatabaseHelper`. Key moved from plaintext `.db_key` file → Keystore-backed
      `SecureStorageService` (`db_encryption_key`), legacy file migrated + deleted.
- [x] **v8 → v9 migration fix** — plaintext v8 DBs would have bricked (SQLite can't
      open plaintext with a key → `SQLITE_NOTADB` 26). Now auto-converted in place:
      plaintext-mode open → `ATTACH` + `sqlcipher_export` → file swap.
- [x] **Session timeout lock** — `SessionTimeoutService`: locks after 5 min
      backgrounded (background time only, no `inactive` false-locks, no
      double-fire). Lock screen prompts the system device credential via
      `KeyguardManager` (`DeviceLockService`, no new dependency).
- [x] **Clipboard guard** — `ClipboardGuard` clears only financial-looking
      clipboard text, only on full background (`paused`), narrow token list
      (testable `isFinancialText`).
- [x] **Root detection** — `RootDetectionService` wired into `main.dart` →
      dismissible `SecurityBanner`; exec moved off the Android main thread.
- [x] **Cleanup** — dead `clearClipboard` channel removed; `flutter analyze`
      clean (13 pre-existing lints fixed); 125 tests passing.

## Repo ops & security (2026-08-19)

- [x] Security audit **started** (see `docs/daily-log/2026-08-19.md`): audited
      Android manifests, Kotlin capture layer, `sms_parser.dart` (partial).
      Findings so far:
  - `WRITE_SMS` + `SEND_SMS` declared but unused → remove.
  - Release build signed with **debug keys** → needs a real signing config.
  - Parser = untrusted-input boundary (spoofed SMS) → ReDoS/validation/fuzz
        hardening is the stress test. Not done yet.
- [x] GitHub branch protection: ruleset `main` created (id 21009654,
      `non_fast_forward` + `deletion`, enforcement active) but
      **`conditions.ref_name.include` is empty** → matches zero branches → NOT
      enforced (force-push probe succeeded). Deferred — user decided optional.
- [x] Known issue: every `gh` token (env + keyring + git credential) returns
      404 on repo API endpoints (`GET /repos/krithik20050/rozz`), while git
      push and `user/repos` work. Root cause unknown; blocks CLI repo ops.

## Ingest & schema fixes (2026-08-19)

- [x] **Data-not-updating bug fixed** (3 root causes, multi-swarm orchestration):
  1. `main.dart` refresh gate — `_refreshAllBlocs()` now always runs after
     drains; new `resumed`-lifecycle refresh (guarded by loaded/onboarding/
     syncing/locked) + post-unlock refresh. Kills stale UI after the 6h
     WorkManager drain.
  2. `transaction_sync_service.dart` JSONL race — read-then-truncate wiped SMS
     appended mid-drain by Kotlin. Now atomic rename → `.draining` → consume →
     append leftovers (never truncate); crash-recovery + concurrent-drain safe.
     Fixed a follow-on splice bug (leftover appended to a newline-less live file
     merged two JSON lines) via `_fileNeedsLeadingNewline`.
  3. `chat_rozz_page.dart` — empty context when insights not loaded (was
     `return ''`); now sends a "not yet computed" summary + refreshes MAB/insights
     before answering.
- [x] **Schema v9 → v10** (panel-reviewed): `getTransactionsByMonth` switched from
      non-sargable `strftime` to a half-open ISO date-range predicate
      (index-able); new `idx_tx_date ON transactions(date DESC)`; `_onUpgrade`
      v1 table-rebuild guarded to `oldVersion < 2` (no more 50k-row copy on
      every bump). Cold-start (Kotlin-created file) still covered.
- [x] 129 tests passing, `flutter analyze` clean.

## Today (2026-08-20) — balance freeze, chat blank replies, MAB fine formula

- [x] **Home balance freeze fixed** — `getLastKnownBalance()` preferred the EOD
      snapshot over a transaction's `balance_after` unless strictly newer. The
      WorkManager EOD task writes a *same-day* mid-day estimate into
      `mab_history` (and reads the same function — circular), so once that row
      landed, every same-day transaction lost and the balance froze all day.
      Now a same-day transaction wins (`>=`); the EOD task's own read then gets
      the freshest value. Tests updated.
- [x] **Chat blank replies fixed** — GROQ's `openai/gpt-oss-120b` is a hidden-CoT
      reasoning model. The request sent `max_tokens` (wrong field for reasoning
      models; GROQ uses `max_completion_tokens`) so the whole 1024 budget
      vanished inside thinking and every reply came back empty with
      `finish_reason: length`. Streaming also ignored `delta.reasoning_content`.
      Now: `max_completion_tokens` (2048), `include_reasoning: false` on GROQ
      chat/stream paths (thinking stays hidden), `sseDeltas` test covers
      reasoning deltas.
- [x] **MAB fine formula corrected** — was a stepped ₹600/₹750/₹1,200 schedule
      (always ≥₹600, wrong). HDFC's actual Regular Savings charge is **6% of the
      shortfall, or a cap, whichever is lower** — ₹600 metro/urban, ₹300
      semi-urban/rural — + GST. `EstimateMabFine` now computes
      `min(shortfall × 6%, cap)`; user-reported real penalty ₹200–300 matches
      (6% of ~₹3.3–5k shortfall).
- [x] 126 tests passing, `flutter analyze` clean. Phone was unplugged —
      device verification of all three pending on next deploy.

## Today (2026-08-20) — device verification + chat 413 fix (GROQ TPM)

- [x] Phone reconnected, deployed `flutter run -d f28ff436 --no-resident`;
      on-device state verified: SQLCipher DB intact + WAL active, home balance
      ₹224.67 renders, transactions render, chat greeting + suggestion chips
      show.
- [x] **NEW on-device bug root-caused: chat 413 Payload Too Large.** GROQ free
      tier `openai/gpt-oss-120b` = 8000 TPM, counted as input tokens +
      `max_completion_tokens`. The chat injected the FULL transaction ledger
      into the request → exceeded 8000 → 413. (The earlier
      `max_completion_tokens` 1024→2048 raise made each request larger.)
- [x] Fixed: chat context ledger capped to latest 100 rows (`_maxLedgerRows`
      in `chat_rozz_page.dart`) with an explicit "latest 100 of N shown — rest
      omitted" note so the model treats a truncated list as incomplete;
      `ai_service.dart` non-200 path now logs the real GROQ error body (the TPM
      limit) instead of a bare status.
- [x] 126 tests passing, `flutter analyze` clean, redeployed to device.
- [ ] STILL OPEN: confirm a real on-device chat reply after the ledger cap
      (re-verification started but inconclusive — message area rendered empty,
      no new stream log yet).
- [ ] STILL OPEN: balance live-update confirmation needs a future real SMS
      (encrypted DB not host-readable).

## Open tasks

- [ ] Finish security hardening: remove `WRITE_SMS`/`SEND_SMS`, fix release
      signing, harden + fuzz the SMS parser (see daily log).
- [ ] Fix GitHub branch protection (add `refs/heads/main` to ruleset
      `include`) and/or re-auth `gh` (404 token issue).
- [ ] **Confirm chat replies on device** — a real reply after the ledger-cap
      fix is still unconfirmed (re-verification inconclusive).
- [ ] **Confirm balance live-update on device** — deferred to the next real
      incoming SMS (encrypted DB not host-readable). Fine estimate is
      unit-tested.
- [ ] Install latest APK on device.
- [ ] App lock / biometric re-enable (stubbed earlier — TODO).
- [ ] Home → transaction-detail navigation (TODO).
- [ ] Next.js + Supabase backend — referenced in docs, NOT in this repo.