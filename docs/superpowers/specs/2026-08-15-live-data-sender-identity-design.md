# Live Data + Sender Identity + Contacts — Design Spec

Date: 2026-08-15
Status: Approved

## Problem

1. The home page shows a hardcoded "COMING UP" block (Netflix ₹649, Internet
   ₹799, Gym ₹1,200) that is fake data unrelated to real transactions.
2. The income tab groups credits by raw recipient name. The user wants known
   senders labeled — e.g. money from UPI ID "KK9396…" should read "father" —
   and per-label monthly totals ("sent by father this month: ₹X").
3. Many people send money via their mobile number (phone-based VPAs like
   `98XXXXXXXX@ybl`). The user wants contacts read from the phone and matched
   by number so the app shows real names.

## Design

### 1. Kill fake data

- Delete the hardcoded `_buildComingUpSection()` on the home page.
- Replace it with a real upcoming-charges card: detected subscriptions
  (already computed by `InsightsBloc`) with a predicted next charge date
  (last occurrence + 1 month), filtered to upcoming, sorted soonest first.
- Mock SMS injection stays dev-only (desktop/web); the phone runs on live SMS.

### 2. Sender identity — auto-detect + manual edit

- New `sender_labels` SQLite table: `key TEXT PRIMARY KEY, label TEXT`.
  DB version 3 → 4. Repo + local datasource follow mab/transactions patterns.
- New pure usecase `ResolveSenderIdentities`:
  - groups credit transactions by normalized sender key (lowercased VPA /
    name, trimmed);
  - resolves display name: **label** (if set) → **contact name** (VPA digits
    match a contact phone) → **title-cased raw name**;
  - with `mergeByIdentity: true`, rows sharing a display name merge into one
    (father's multiple VPAs become one "father" row);
  - output: per-key `ResolvedSender` list + merged-by-identity income sources.
- Income tab shows merged identity rows — "sent by father this month: ₹X".
- New "manage senders" screen: lists every detected sender (name, count, total
  this month); tap to set/edit/remove a label. Persists to `sender_labels`.

### 3. Contacts matching

- Add `flutter_contacts` (^2.3.1) + `android.permission.READ_CONTACTS` to the
  manifest. Request permission on first use (permission_handler already used).
- New `ContactResolver` service: loads contacts once (name + phones, cached),
  normalizes every phone to its last 10 digits → `Map<phone10, name>`.
  Takes an injectable loader for testability.
- Matching: extract the digit run from the sender VPA (`98XXXXXXXX@ybl` →
  last 10 digits); match against the normalized contact map. No permission →
  app works identically without names.

### 4. Architecture

- Feature-first clean architecture, BLoC only. `InsightsBloc` gains
  `ComputeUpcomingCharges`, `ResolveSenderIdentities`, `SenderLabelRepository`,
  `ContactResolver`; state carries `upcomingCharges`, `senders`,
  `senderLabels`, and redefined `incomeSources` (identity-merged).
  Events: `LoadInsights`, `SaveSenderLabel`, `DeleteSenderLabel` (reload).
- Home page reads upcoming charges from `InsightsLoaded` via `BlocBuilder`.

### 5. Testing

- Unit tests: `ResolveSenderIdentities` (label wins, contact phone match,
  digit normalization, merge), `ComputeUpcomingCharges` (next-date
  prediction, filtering, sorting), phone/VPA digit extraction.
- Update `ComputeIncomeSources` tests → replaced by `ResolveSenderIdentities`.
- DB datasource test for `sender_labels` (insert/update/delete/read).
- `flutter analyze` + full `flutter test`.
