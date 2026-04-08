# ROZZ - Project Progress

## Phase 1: Complete UI (Status: COMPLETED)
- [x] Feature-first architecture implemented (lib/features/).
- [x] Onboarding screens (Fake data navigation).
- [x] Home screen with summary widgets.
- [x] Transactions list (Real-looking Indian names/amounts).
- [x] MAB (Monthly Average Balance) screens.
- [x] Insights & Analytics UI.
- [x] Sync & Settings pages.
- [x] Skeleton loaders for all lists.
- [x] Empty & Error states for all screens.
- [x] Navigation wired throughout the app.
- [x] Dark premium UI (#080810 background).
- [x] DM Mono font for financial numbers.
- [x] Syne Bold for hero numbers.

## Phase 2: Logic & Automation (Status: COMPLETED)

### Phase 2 Tasks
1. **Security Setup:**
   - [x] Android Keystore (flutter_secure_storage).
   - [x] Enable FLAG_SECURE on MainActivity.
2. **Database Layer:**
   - [x] SQLite (sqflite) with WAL mode enabled.
   - [x] Schemas for Transactions (with category), MAB history, UPI memory, Settings.
   - [x] WriteQueue for thread-safe DB writes.
3. **Node.js Bridge:**
   - [x] Integrate flutter_js for SMS parsing.
   - [x] JS bridge via flutter_js JavascriptRuntime with regex patterns.
4. **SMS Parsing (Phase 2 Core):**
   - [x] SMS BroadcastReceiver (priority 999) in Android.
   - [x] Dart SmsParser with 5 HDFC patterns (UPI Debit/Credit, ATM, NEFT, MAB Fine).
   - [x] Fixed `fromSms` factory bug (`label_type` key).
5. **Background Work:**
   - [x] WorkManager EOD balance snapshot (every 12 h) with backfill.
   - [x] WorkManager Gemini sync task (every 24 h, network required).
6. **Gemini Integration:**
   - [x] Gemini 2.0 Flash REST categorization with retry/timeout.
   - [x] Background categorization of uncategorized transactions via WorkManager.
   - [x] Settings page to securely enter/save/clear Gemini API key.
7. **Business Logic (BLoC):**
   - [x] TransactionBloc wired to SQLite repository.
   - [x] MabBloc wired to SQLite repository with real daily balance records.
   - [x] MabChart now uses real `monthRecords` from MabBloc state.
   - [x] BalanceHero now shows real today's spend computed from transactions.
   - [x] TransactionCard shows `category` (or formatted `labelType`) instead of placeholder.
   - [x] `category` field added to Transaction entity, model, datasource, and repository.

## Phase 3: Cloud Sync & Insights (Status: COMPLETED)
- [x] Supabase cloud sync for transactions and MAB history (`lib/core/services/supabase_service.dart`).
- [x] `SyncService` — bidirectional push/pull with device-scoped rows (`lib/features/sync/sync_service.dart`).
- [x] Cross-device sync: upsert transactions on conflict(device_id, local_id); upsert MAB on conflict(device_id, date).
- [x] Settings page extended with Supabase URL + anon key fields, "Save & Connect", "Sync Now" button, last-synced timestamp.
- [x] Auto-sync on app open when Supabase is configured.
- [x] Rich financial insights dashboard (`lib/features/insights/`):
  - [x] Monthly spend bar chart (last 6 months) — `MonthlySpendChart`.
  - [x] This-month summary card (spent / received / net / avg per day).
  - [x] Category breakdown with animated progress bars — `CategoryBreakdown`.
  - [x] Top 5 payees ranked by spend.
- [x] Third nav-bar icon (bar chart) in `MainScaffold` leads to `InsightsPage`.
- [x] `copilot-setup-steps.yml` added — Flutter + Java pre-installed for every future Copilot session.

