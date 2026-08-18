# Insights Full Pass — Design Spec

Date: 2026-08-15
Status: Approved (scope confirmed: detection-only subscriptions)

## Problem

The Insights page has four tabs (for you / spending / subscriptions / income)
that are purely decorative — tapping one only changes the highlight, never the
content. Errors render as an empty gap (silent failure). There is no
pull-to-refresh and no empty state for a fresh user.

## Design

Feature-first clean architecture, BLoC only. All data already flows through
`InsightsBloc` (monthly summary + subscriptions) and `MabBloc` (health/streak);
no schema or repository changes. New domain logic is a pure usecase.

### 1. Real tabs

Each tab's content becomes a widget under `presentation/widgets/`:

- **for you** — curated dashboard (below).
- **spending** — month header, total spent + % change vs prior month, ranked
  category breakdown: icon, name, amount, share of total, proportion bar,
  prior-month comparison.
- **subscriptions** — total monthly (+ yearly) cost header, full list instead
  of 4 avatar badges: merchant avatar, name, monthly amount, occurrences, last
  charge date. Detection-only (from real history) — no manual entry.
- **income** — received this month vs last month, net saved, top income
  sources (credits grouped by recipient: name, amount, count).

### 2. Richer "for you" dashboard

Add a received / spent / saved stat row with month-over-month deltas above the
existing health banner, streak, spending highlight, and subscription watch.
The monthly-review entry card stays.

### 3. Polish + reliability

- Error state: replace `SizedBox.shrink()` silent failure with the shared
  `ErrorState` widget + retry re-dispatching `LoadInsights` / `LoadMabStatus`.
- Pull-to-refresh via `RefreshIndicator`.
- Empty states: friendly message cards for no categories / subscriptions /
  income yet.
- Month context per tab (e.g. "august 2026") anchors the numbers.

### 4. New domain code

- `domain/entities/income_source.dart` + `domain/usecases/compute_income_sources.dart`
  — pure function: credits grouped by normalized recipient, sorted by amount
  descending. Mirrors `ComputeSubscriptions` style.
- `InsightsBloc` gains the usecase as a constructor dependency;
  `InsightsLoaded` carries `incomeSources`.

### 5. Testing

- New unit test for `ComputeIncomeSources` (empty, grouping, sorting,
  case-insensitivity).
- Update `insights_bloc_test.dart` to assert income sources land in state.
- `flutter analyze` + full `flutter test` to verify no regressions.
