# Insights Full Pass Implementation Plan

**Goal:** Turn the Insights page's decorative tabs into real views (for you / spending / subscriptions / income), enrich the "for you" dashboard with a received-spent-saved stat row, and add error/empty states + pull-to-refresh.

**Architecture:** Feature-first clean architecture, BLoC only. New domain logic is a pure usecase (`ComputeIncomeSources`); `InsightsLoaded` gains one field. The page becomes a tab orchestrator; each tab is a widget under `presentation/widgets/`.

**Tech Stack:** Flutter, flutter_bloc, equatable, google_fonts, intl, MerchantBrandResolver (shared).

---

## File Map

**Create:**
- `lib/features/insights/domain/entities/income_source.dart`
- `lib/features/insights/domain/usecases/compute_income_sources.dart`
- `lib/features/insights/presentation/widgets/insights_shared.dart` — `categoryIcon()`, `changeLine()`, `monthLabel()` shared helpers
- `lib/features/insights/presentation/widgets/for_you_tab.dart`
- `lib/features/insights/presentation/widgets/spending_tab.dart`
- `lib/features/insights/presentation/widgets/subscriptions_tab.dart`
- `lib/features/insights/presentation/widgets/income_tab.dart`
- `test/features/insights/domain/usecases/compute_income_sources_test.dart`

**Modify:**
- `lib/features/insights/presentation/bloc/insights_state.dart` — add `incomeSources` to `InsightsLoaded`
- `lib/features/insights/presentation/bloc/insights_bloc.dart` — inject + compute income sources
- `lib/features/insights/presentation/pages/insights_page.dart` — real tabs, RefreshIndicator, error/empty states
- `lib/main.dart` — pass `ComputeIncomeSources()` to `InsightsBloc`
- `test/features/insights/presentation/bloc/insights_bloc_test.dart` — assert income sources

## Task 1: Domain — IncomeSource entity + usecase (TDD)

Entity: `recipient` (String), `amount` (double), `count` (int). Usecase: credits only, group by lowercased/trimmed recipient, title-case display name, sort by amount desc.

## Task 2: Bloc — carry income sources in state

`InsightsLoaded` gains `incomeSources`; bloc constructor gains `ComputeIncomeSources`; `_onLoadInsights` computes from current-month transactions. Update `main.dart` wiring.

## Task 3: Shared helpers

Extract `categoryIcon(String)`, `changeLine(CategorySpend, NumberFormat)`, `monthLabel(int, int)` into `insights_shared.dart` so all tabs reuse one vocabulary.

## Task 4: Tab widgets

- **for_you_tab**: month pill, received/spent/saved stat row with prior-month deltas, monthly-review entry, MAB health banner (from MabBloc), balance streak, spending highlight, subscription watch — the current page content + new stat row.
- **spending_tab**: month pill, "spent X · ±Y% vs last month", ranked category rows (icon, name, amount, % share, proportion bar, change line), empty state.
- **subscriptions_tab**: monthly/yearly total header, full list (avatar, name, monthly amount, occurrences, last charge date), empty state.
- **income_tab**: month pill, received vs prior + delta, saved, top income sources list (recipient, amount, count), empty state.

## Task 5: Page — real tabs + polish

`_selectedTab` switches content via a switch expression; `RefreshIndicator` re-dispatches `LoadInsights` + `LoadMabStatus`; `InsightsError` shows `ErrorState` with retry; per-tab empty states.

## Task 6: Tests + verify

New usecase tests (empty, grouping, sort, case-insensitivity, debits ignored). Update bloc test for `incomeSources`. Run `flutter analyze` and `flutter test` in `rozz_app/`.
