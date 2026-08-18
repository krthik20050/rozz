# AI Chat Full-Record + Classification with Doubt-Asking

**Goal:** (1) Chat answers from the *entire* financial record, always fresh ("day to date"), finance-tilted; (2) a categorizer that learns — unsupervised (LLM zero-shot) for unknown merchants, supervised (user-confirmed merchant mappings) for known ones, and *asks the user* when in doubt.

**Current state (already done, don't rebuild):**
- Chat page (`features/chat/`) sends a month summary + top-15 txs, carries 10-turn history, PII-redacts, intent-gates finance questions.
- `AiService.categorizeTransaction()` exists but: no category vocabulary, no confidence, no user feedback, no reuse.

**Architecture:** Feature-first clean architecture, BLoC only. No new dependencies — SQLite FTS5 (fallback: `LIKE`) + the existing `AiService`. No on-device model training; "learning" = a merchant→category table written from user confirmations.

---

## Part 1 — Chat answers from the full record

### Task 1: Fresh context at ask-time (not BLoC state)
`chat_rozz_page.dart` builds context from `InsightsBloc` state, which can be stale. Change `_buildContext` to read the repositories directly (month aggregates computed in Dart from `getAllTransactions()`, MAB from `MabBloc` as today). Refresh happens per question — that's the "day to date" guarantee. No new BLoC.

### Task 2: Intent-aware retrieval (the "all my questions" gap)
The top-15 slice can't answer "March 2025", "how much to Zomato", "year so far". Add:
- `searchTransactions(String query)` on `TransactionRepository` → FTS5 over narration/recipient/upi (`LIKE` fallback), newest first, limit ~50.
- `_buildContext` parses the question for a **time window** (this month / last month / a month / this year) and **keywords** (merchant, category, sender name). Matches fetch targeted rows; aggregations (sum spent/received, per-merchant, per-category) computed in Dart from the fetched set.
- Context stays compact (~5KB cap): aggregates first, a few representative rows. Free-tier models stay cheap; PII redaction applies to every row as today.

### Task 3: Wider intent gate
Extend `isFinancialQuestion` keywords (clothing, music, entertainment, gym, emi, sip, nps, etc.). Non-finance questions already skip data — keep that.

### Task 4: Tests + verify
- `searchTransactions` tests (FTS + LIKE path, empty query, limit).
- Context-builder tests: stale-state independence, date-window parsing, keyword→rows.
- `flutter analyze` + `flutter test` in `rozz_app/`.

---

## Part 2 — Classification that learns and asks when unsure

Mapping your supervised/unsupervised idea to something that runs on a phone:
- **Unsupervised path:** LLM zero-shot on narration+merchant → `{category, confidence}`. Used only when no learned mapping exists.
- **Supervised path:** `merchant_mapping` table (merchant key → category, user-confirmed). Known merchant → category applied locally, no LLM call, free + offline + instant. Every user answer is a training example.
- **Doubt → ask:** low confidence **or** unknown merchant → don't auto-apply; ask the user (confirm card in chat / on the transaction). Their answer writes the mapping.

### Task 5: Category vocabulary (one source of truth)
Fixed const list in domain: `Food, Transport, Shopping, Clothing, Entertainment, Music, Rent, Salary, Bills, Health, Groceries, Other`. Keep existing insight categories aligned (CONTEXT.md goal: one vocabulary). Categories the user named (clothing, entertainment, music, food) are in it.

### Task 6: Classifier v2 — `categorizeTransaction` returns JSON
Prompt: *"Narration: … Merchant: … → pick ONE category from [list]; reply JSON only: `{"category": "...", "confidence": 0.0-1.0}`"*. Parse + validate against the vocabulary (invalid → treat as low confidence). Confidence in the prompt biases models toward honesty on ambiguous narrations.

### Task 7: Merchant mapping store
New table `merchant_mapping(merchant_key, category, source, updated_at)` via `DatabaseHelper`. Key = normalized recipient (lowercase, trim, strip emojis/spaces). Repository + methods: `lookup(merchant)`, `save(merchant, category)`. Lookup wins over LLM; LLM wins over nothing; user wins over both.

### Task 8: Ask-on-doubt flow
On ingest/sync: category + confidence computed per new transaction. If mapping hit → apply, done. Else LLM; confidence ≥ 0.7 → apply + persist nothing (re-evaluate later if merchant repeats). Confidence < 0.7 or LLM unavailable → mark transaction `needs_review`, surface in chat ("I couldn't tell if X is Food or Entertainment — tap to correct") and as a badge on the transaction row. User answer → `save()` mapping + update transaction.

### Task 9: Learning metric
Store `category_source` on the transaction (mapping / llm / user). Insights gains one line: *auto-apply rate* = (mapping + llm-applied) / total. This is the "is it learning" number — rises as mappings accumulate.

### Task 10: Tests + verify
- Prompt→JSON parsing tests (valid, malformed, out-of-vocab, missing fields).
- Mapping lookup precedence tests (mapping > llm > nothing; user overwrite).
- Confidence-gate tests (apply vs needs_review).
- `flutter analyze` + `flutter test`.

---

## File Map

**Create:**
- `lib/features/transactions/domain/entities/category_vocabulary.dart` — const category list
- `lib/features/transactions/data/models/categorization_result.dart` — `{category, confidence}`
- `lib/features/transactions/data/datasources/merchant_mapping_datasource.dart` (or fold into `transaction_local_datasource.dart`)
- `lib/features/chat/domain/chat_context_builder.dart` — intent-aware context (testable, pure Dart)
- `lib/features/chat/domain/question_intent.dart` — time-window + keyword parsing
- tests for each

**Modify:**
- `transaction_local_datasource.dart` / `transaction_repository.dart` — `searchTransactions()`, merchant-mapping methods, `category_source` column (migration)
- `ai_service.dart` — `categorizeTransaction` → JSON + confidence (keep old callers working)
- `chat_rozz_page.dart` — use `ChatContextBuilder`, add ask-on-doubt confirm card
- transactions UI — `needs_review` badge + tap-to-correct
- insights — auto-apply rate line

---

## Order

1. Tasks 1–4 (chat full-record) — user-visible immediately.
2. Tasks 5–8 (classifier + learning loop).
3. Tasks 9–10 (metric + verification).

Skipped for now: embeddings/vector search (FTS5 + aggregations cover finance questions; add Gemini embeddings only if free-form queries like "spent on dates" underperform), on-device model training (merchant table is the lazy supervised model), a separate review screen (confirm-in-chat covers it).