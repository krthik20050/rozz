# Decisions — ROZZ

ADR-style record of architectural and technical decisions. One numbered entry
per decision, appended in order. See `docs/daily-log/` for the day-to-day trail
these decisions came from.

## ADR-001 — Use `max_completion_tokens` (not `max_tokens`) for GROQ reasoning models

**Status:** Accepted (2026-08-20)

**Context:** `openai/gpt-oss-120b` on GROQ is a hidden-CoT reasoning model. Chat
replies came back empty with `finish_reason: length`. The request body used
OpenAI's legacy `max_tokens` field.

**Decision:** Send `max_completion_tokens` (raised to 2048) instead of
`max_tokens`, and add `include_reasoning: false` on the GROQ chat + streaming
paths (keep thinking hidden — the user wants answers, not a CoT dump).
`sseDeltas()` now also skips `delta.reasoning_content`.

**Evidence:** `max_tokens` is the wrong field for reasoning models; GROQ
requires `max_completion_tokens`, which reserves budget for reasoning + output.
With a 1024 budget the whole allocation vanished inside thinking → empty
content, `finish_reason: length`.

**Alternatives considered:** (a) keep `max_tokens` and raise the budget — doesn't
fix reasoning-model semantics, can still return empty; (b) strip reasoning
client-side — fixes display, but the token budget was still consumed
server-side by reasoning.

**Why this is better:** correct field per GROQ/OpenAI reasoning-model spec; 2048
leaves real room for an answer; gating `include_reasoning: false` to the GROQ
chat path (model == null) leaves the faster categorization path
(`openai/gpt-oss-20b`) untouched.

**Downsides / follow-ups:** the 2048 raise made requests larger, which combined
with the full-ledger context hit GROQ's TPM cap → see ADR-002.

## ADR-002 — Cap the chat context ledger (GROQ free-tier 8000 TPM)

**Status:** Accepted (2026-08-20)

**Context:** on-device verification of ADR-001 produced `Chat stream status: 413`
(Payload Too Large) in logcat.

**Evidence:** GROQ free tier `openai/gpt-oss-120b` = 8000 TPM, counted as input
tokens + `max_completion_tokens`. GROQ's real error body:
`"Request too large ... on tokens per minute (TPM): Limit 8000, Requested NNNNN"`.
The chat context builder (`chat_rozz_page.dart:_buildContext`) injected the FULL
transaction ledger (every row) so the model could answer about any month — that
single block is what blew past 8000.

**Decision:** cap the ledger in the chat context to the latest 100 rows
(`static const _maxLedgerRows = 100`) and tell the model explicitly how many were
shown vs omitted ("latest 100 of N shown — the rest are omitted") so it doesn't
treat a truncated list as complete. Also: `ai_service.dart` now reads and logs
the real GROQ error body on non-200 so future failures are self-explanatory.

**Alternatives considered:** (a) keep the full ledger and shrink
`max_completion_tokens` — shrinks answers to fit the budget, wrong trade-off;
(b) page/retrieve on demand — real fix for arbitrarily large histories but a
bigger feature; (c) move to a paid/dev GROQ tier — real fix but costs money.

**Why this is better:** free tier keeps working now with the cheapest change;
the explicit truncation note keeps answer quality honest; the error-body logging
makes the next tier limit self-diagnosing.

**Downsides / follow-ups:** the 100-row cap means answers about very old months
lose detail; if the ledger persistently exceeds ~8000 TPM, revisit with
on-demand retrieval or a paid tier.

## ADR-003 — Same-day transaction `balance_after` wins over the mid-day EOD snapshot

**Status:** Accepted (2026-08-20)

**Context:** home balance froze all day. `getLastKnownBalance()` preferred the
EOD snapshot unless strictly newer.

**Evidence:** the WorkManager EOD task writes a SAME-DAY mid-day estimate into
`mab_history` and reads the same function — circular. Once that row landed,
every same-day transaction lost the balance and the figure never updated.

**Decision:** a same-day transaction's `balance_after` now wins (`>=`
comparison); the EOD task's own read then gets the freshest value.

**Alternatives considered:** timestamp tie-breaking hacks; separate reads for
EOD vs display.

**Why this is better:** matches the domain rule "Balance snapshot is source of
truth" without breaking intra-day freshness; unit-tested.

**Downsides / follow-ups:** on-device confirmation requires a future real SMS
(encrypted DB is not host-readable).

## ADR-004 — MAB fine = min(shortfall × 6%, cap) + GST

**Status:** Accepted (2026-08-20)

**Context:** `EstimateMabFine` used a stepped ₹600/₹750/₹1,200 schedule — always
≥₹600, wrong per HDFC's real scheme.

**Evidence:** HDFC Regular Savings charge = 6% of the shortfall or a cap,
whichever is lower — ₹600 metro/urban, ₹300 semi-urban/rural — + GST.
User-reported real penalties of ₹200–300 match 6% of ~₹3.3–5k shortfalls.

**Decision:** compute `min(shortfall × 6%, cap)` + GST.

**Alternatives considered:** keep the stepped schedule (over-penalizes small
shortfalls).

**Why this is better:** matches the bank's actual formula and real user data.

**Downsides / follow-ups:** none known; cap value depends on account location
(metro vs semi-urban/rural) — keep configurable if users report mismatches.

## ADR-005 — On-device verification discipline / adb quirks

**Status:** Accepted (2026-08-20)

**Context:** verifying on a physical device required adb-driven UI taps; `input
text` mangled input (adb `%s` escapes), the Enter keyevent added newlines
instead of submitting, and send-button coordinates shift when the keyboard is up.

**Decision:** drive chat via suggestion chips + explicit send-button taps
located fresh from `uiautomator dump` each time; check `flutter`-tagged logcat
(not a raw logcat grep) for stream status.

**Why this is better:** reliable, reproducible UI verification on MIUI/Xiaomi
without an instrumentation harness.

**Downsides / follow-ups:** manual-ish; revisit with a proper widget/integration
test harness if verification frequency grows.

---

Decisions may be revisited; update this file when they change.
