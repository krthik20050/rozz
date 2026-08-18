# CONTEXT — ROZZ domain language

Terms the codebase and this conversation use. Keep these exact; don't drift into
"service", "component", "widget", or "data".

- **Transaction** — a single movement of money (debit or credit) captured from an
  SMS. Fields: amount, direction, label type, recipient name, optional
  balance-after, UPI ref, raw SMS, optional category.
- **Narration** — the human-meaningful description of a transaction. Golden rule
  (from rozz-architecture.md): *most detailed source wins* — user > WhatsApp PDF
  > HDFC API > SMS. Today only the SMS source exists.
- **MAB (Monthly Average Balance)** — sum of daily closing (EOD) balances divided
  by the days in the month; threshold ₹10,000. Zones: safe / middle / danger /
  fine (penalty).
- **Balance snapshot** — an end-of-day (EOD) balance recorded from HDFC's daily
  balance-advice SMS or the EOD background task. Lives in `mab_history`. The
  source of truth for "current balance" — not the last transaction's
  balance-after.
- **Category** — the spend classification of a transaction (Food, Transport,
  Shopping, …). Sources today: AI (stored on the transaction) and the
  merchant-brand resolver (display only). Goal: one vocabulary, one source of
  truth.
- **Insight** — a computed statement about the user's finances derived from
  transactions + balance history: spend by category, subscriptions, streak,
  monthly summary. Screens display insights; they never display literals.
- **Subscription** — a recurring monthly charge detected from transaction
  history (same merchant, similar amount, across two or more months). Detected
  locally; never a hardcoded list.
- **Balance streak** — how many recorded days in a month kept the balance at or
  above the MAB threshold. The denominator is days *recorded*, so a partial
  month stays honest.
- **Ingest** — turning captured SMS into transactions and balance snapshots (the
  pipeline: capture → parse → route → dedupe).
