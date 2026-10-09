# ROZZ design theme study

2026-10-09. Theme exploration only; working Flutter UI unchanged. Concept data is fictional.

## Diagnosis from current code

colors.dart uses violet #7C6AF7 and purple-tinted surface layers. balance_hero.dart combines a radial glow, backdrop blur, translucent panel and rounded border. Changing the accent alone would leave the same visual structure. Remove decorative gradients/glows, simplify surfaces, use one dominant sans family and tabular digits, and reserve color for meaning. The hardcoded greeting/name should become appropriate user data or a neutral heading.

## Primary references researched

- Copilot Money: https://www.copilot.money/ . Product page demonstrates transaction review, spending/cashflow views, recurring charges, and account freshness timestamps. Interpretation for ROZZ: freshness belongs beside the balance; review and correction belong on transaction details.
- Monzo: https://monzo.com/help/monzo-perks/trends-spending-and-balance-web . Official documentation separates spending, balance over time and targets. Interpretation: a purposeful MAB threshold chart communicates more than a decorative dashboard chart.
- Fold: https://fold.money/ . Official page shows balance trends, account information, merchant search and transaction filters. Interpretation: open readable transaction lists and useful search should receive priority. Its Account Aggregator integration is separate from design inspiration and does not establish free API access for ROZZ.

These are product-pattern findings from official pages, not an exhaustive hands-on usability audit.

## Three directions

| Direction | Composition | Palette | Tradeoff |
|---|---|---|---|
| Quiet Ledger (recommended) | Balance first, compact MAB module, generous open transaction list | #111315 background, #1B1E21 surface, #F4F5F2 text, #92999D secondary, #71B88A positive, #D8AF62 threshold | Best everyday scan; fewer decorative brand elements |
| Balance Instrument | MAB first, large daily closing balance chart, secondary balance | #111820 background, #1C2631 surface, #F2F6FA text, #9BA8B5 secondary, #80BFFF chart, #D8AF62 threshold | Strongest for MAB monitoring; chart takes more space |
| Personal Journal | Monthly heading, balance, paired MAB/minimum figures, dated ledger groups | #191816 background, #25231F surface, #F1EEE5 text, #A39D92 secondary, #C6A261 accent, #79B394 positive | Warm and approachable; trend needs a drill-down |

Each direction stays dark and uses four clear destinations: Overview, Activity, Insights, Ask. This navigation is a proposal; preserve all existing features during implementation. Settings accessible from header. No gradients, glow, decorative glass, category rainbow or nested card stacks. Native font scaling and 44pt minimum interaction targets. Currency is easy to scan, but not every label needs monospace.

## Useful improvements, in priority order

1. Balance source and age: bank-reported versus replayed estimate, last bank anchor, unknown/stale states. Do not label an inferred balance bank-confirmed today. Preserve existing provenance metadata.
2. MAB detail: recorded daily closing balances, minimum line, recorded-day coverage, distinct month-to-date versus final-month average. Forecast must be visibly separate from observed data. Gaps stay visible.
3. Activity: merchant search, direction/category filters, date groups, transaction detail, category correction and ingestion source. Reuse current repositories and BLoCs.
4. Computed insights: recurring charges with dismissal, actual category totals, and meaningful monthly changes. No hardcoded financial advice or fabricated safe-to-spend figures.
5. Responsive states: accessible text, skeleton/empty/error/stale states, reduced motion, consistent icon weight, readable secondary text.

## Next implementation slice

Choose a direction after reviewing the concept board. Apply tokens and redesign Overview plus transaction row first, preserving database/ingest/MAB logic. Compare in Windows preview with normal, empty, stale and missing-anchor data before extending to Activity, MAB detail, Insights and Ask. No paid assets or service dependencies required.

Concept board: [three theme concepts](design/theme-concepts.png). Generated illustration, not a functional screenshot: chart values, dates and freshness wording are illustrative. Implementation must calculate chart points from actual recorded EOD balances and label the average month-to-date; timestamps must use actual source metadata.
