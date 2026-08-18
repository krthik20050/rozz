# ROZZ UI/UX Research — Loading, Micro-interactions, Glass, Onboarding

Date: 2026-08-15
Status: Research & recommendations (not yet implemented)

## 1. What the research says (sourced)

### 1.1 Skeleton screens — they work, but the details matter

The most rigorous public study on skeleton screens (Bill Chung, UX Collective,
2018, street-tested on physical devices) found:

- Skeleton screens are **perceived as shorter** than a blank screen or a
  spinner — but only modestly. They are not magic; they buy a little time, not
  a lot.
- **Motion matters more than the shape.** Skeletons with a left-to-right
  shimmer/wave (Facebook/Google style) are perceived as faster than pulsing
  (fade in/out) skeletons.
- **Slow, steady shimmer beats fast/rapid motion.**
- Skeletons must be **progressive**: real content replaces each placeholder the
  instant its data arrives. Blocking full-screen skeletons (splash-style) are
  the *original anti-pattern* — Luke Wroblewski coined "skeleton screen" to get
  away from "watching the clock"; a full-page skeleton is just a fancier clock.
- NN/g (2023): skeletons signal layout and content position early, which
  reduces perceived wait vs spinners, but only when the placeholder matches the
  final layout — a mismatched skeleton actually *increases* perceived load.

Implications for ROZZ:
- Shimmer, left-to-right, slow, matching final layout. Not pulse, not fast.
- Per-card progressive loading (each card fills as its bloc resolves) rather
  than a full-page skeleton on every tab switch.

### 1.2 Micro-interactions — trust is the currency in fintech

Research across banking/fintech UX (42Flows, Muzli, IXDF, Marvel) converges on
four jobs micro-interactions do in a money app:

1. **Reassurance/trust** — real-time feedback that an action is being
   processed ("secure transaction" progress), an animated checkmark on
   success. Trust is the #1 differentiator in finance UX.
2. **Error prevention** — shake on wrong PIN, disable + visual feedback on
   invalid input *before* submission.
3. **Direct manipulation** — swipe-to-confirm, tap ripple, toggle that slides
   like a physical switch (follow real-world physics).
4. **Delight/milestones** — confetti or badge on savings goals reached,
   animated counters on balances (already partly present via
   `AnimatedCounter`).

Every micro-interaction follows the Trigger → Rule → Feedback → Loop cycle, and
the consistent best-practice warning is: **functional, subtle, physics-based,
never slow or gimmicky.** Excess animation reads as untrustworthy in finance.

### 1.3 Glass morphism / Liquid Glass — the cautionary tale

- Apple shipped **Liquid Glass** system-wide in iOS 26 (WWDC 2025) — frosted,
  refractive, layered glass across controls, tab bars, and cards.
- **NN/g tested it and published a critical usability review ("Liquid Glass Is
  Cracked", Oct 2025):** translucent controls over noisy backgrounds lose
  contrast, tap targets shrink and crowd, controls appear/disappear
  unpredictably, and text becomes hard to read. Accessibility suffers badly
  (low-vision users; the standard remedy is "Reduce Transparency").
- The reddit/designer consensus matches: Liquid Glass is loved on visionOS
  (spatial) but criticized on flat mobile screens for readability.

Implications for ROZZ (a **dark, data-dense** Android finance app):
- Use glass as **accent, not surface**: frosted-blur cards *over* a subtle
  gradient/glow background, keeping **text contrast high** and tap targets
  full-size. Do not make every card translucent.
- In Flutter this is very achievable: `BackdropFilter` + `ImageFilter.blur`
  gives true glassmorphism (content behind the card blurs through). The app's
  existing dark theme + gold glow (RozzColors.goldGlow) is a strong base.
- Always pair glass with solid fallbacks: keep borders, keep opacity ≥ ~85%
  for text-bearing surfaces, and never place text on bare glass over busy
  background.

### 1.4 Fintech onboarding — short, safe, progressive

Hard data (Incognia Friction Index, Fenergo, Signicat — via UserPilot/Eleken):

- Average mobile fintech onboarding = **14 screens, 29 clicks, 16 form fields,
  ~6 minutes**. Users give up on financial apps after ~19 minutes.
- **70% of finance companies lost clients to inefficient onboarding** (2025,
  Fenergo); 92% worry about sharing personal data, 21% abandon over it.
- Best-practice patterns that reduce drop-off:
  - **Progressive onboarding**: essential first, everything else later.
  - **Value-first**: show the user their data/insight *before* asking for
    more permissions. For ROZZ: the SMS sync itself is the onboarding — the
    app should celebrate "your balance is live" the moment the first real SMS
    parses.
  - **Explain why for every permission** — users abandon when they don't
    understand why they're asked. ("Contacts are matched privately on your
    phone to name the people sending you money.")
  - **Skip-able walkthrough**: 1–3 screens max, animated, with a visible
    progress indicator, never a hard gate.

### 1.5 Error / empty / offline states — the forgotten UX

- NN/g: never default to a truly empty state; use it to explain *why* and give
  the next step. Empty ≠ blank.
- Best practices across sources: icon/illustration + plain-language reason +
  **one clear call-to-action** (retry button, "sync now", "grant permission").
- Finance apps get **error-state anxiety** because money feels at stake:
  an error must look recoverable and calm — muted red, clear "what happened",
  a working retry, and never a raw stack trace.

## 2. Recommendations for ROZZ

### A. Loading system (replace the current static skeletons)

Current state: `_buildLoading()` in InsightsPage is a set of static gray
boxes; home uses `ShimmerCard`. No shimmer motion, no progressive fill.

1. **Build one `ShimmerSkeleton` widget** (animated, left-to-right, slow
   sweep) and a `SkeletonCard` set (avatar circle, title bar, two text lines)
   that matches the real card layout — so skeletons look like the final UI.
2. **Progressive loading**: keep stale data on screen while refreshing
   (pull-to-refresh already reloads blocs; don't blank the page to a skeleton
   on refresh). Show skeletons only on first load; subsequent loads fade/slide
   new data in.
3. **Per-block skeletons, not full-page**: home = balance-hero skeleton +
   upcoming-charges skeleton + list skeletons, each resolving independently as
   its bloc lands.
4. **Animated transitions**: when data arrives, skeleton → real content with a
   subtle fade/slide (AnimatedSwitcher), and numbers count up (AnimatedCounter
   already exists — use it for balance, spent, received).

### B. Micro-interactions to add (in priority order)

1. **Animated number counters** everywhere money appears (balance hero,
   received/spent/saved stats, subscription totals). Already have
   `AnimatedCounter` — extend usage.
2. **Tap feedback**: ripple/scale on every card and button (InkWell /
   GestureDetector + scale-down on press). Cards currently have no press
   state.
3. **Success feedback on label save**: when naming a sender in "manage
   senders", show an animated checkmark + the income row updates with a
   highlight flash — this is the app's "payment success" equivalent and builds
   trust.
4. **Refresh indicator polish**: color, haptic on pull (`HapticFeedback`),
   and a small "updated just now" toast after refresh completes.
5. **Tab switching animation**: fade/slide between insights tabs (AnimatedSwitcher),
   and the segmented control already animates — extend it with a sliding
   pill indicator.
6. **MAB zone transitions**: when the MAB zone changes (safe→danger), animate
   the banner color change and flash the icon; a subtle haptic on entering
   danger.
7. **Shake-on-error** for any input (future: PIN, amounts) — feedback before
   submission.
8. **Haptics** (HapticFeedback.lightImpact) on: card taps, tab switches,
   refresh complete, label saved. Physical feedback = perceived quality.

### C. Glass morphism / Liquid Glass — as accent, carefully

1. **Floating dock nav bar**: make it a frosted glass bar (`BackdropFilter`
   blur over content as it scrolls beneath) — this is the single highest-visual-
   impact glass element and is standard in modern fintech.
2. **Balance hero card**: subtle glass overlay on a gold-tinted gradient glow;
   keep the number on a solid, high-contrast layer.
3. **Modal bottom sheets** (transaction details, name-a-sender): frosted top
   edge / backdrop blur behind the sheet for depth.
4. **Never** translucent text surfaces: all body text stays on `s1`/`s2`
   solid or ≥90% opaque surfaces. Follow NN/g's critique: keep borders,
   keep tap targets ≥ 48dp, verify contrast (WCAG AA) on the glass areas.
5. Add a subtle **glow/refraction** (existing goldGlow/accentGlow) instead of
   full transparency where contrast matters.

### D. Onboarding (new — the app currently has none)

The app currently dives straight into SMS permission. Redesign as a
**3-screen animated walkthrough + progressive permission flow**:

1. **Screen 1 — value promise**: "ROZZ reads your bank SMS on-device to show
   your real balance, MAB health, and what's coming." One line, strong visual
   (animated balance card).
2. **Screen 2 — privacy, the fintech trust point**: "Nothing leaves your
   phone — parsing, categorization, and contact matching all happen locally."
   This directly addresses the 92%-worry-about-data stat.
3. **Screen 3 — what you'll see**: mini previews of home / insights, then
   **one** permission ask (SMS) with a *why* line. Skip button always visible.
4. **Post-permission, value-first**: the moment the first real SMS parses,
   show a "your balance is live 🎉" moment (confetti-scale or checkmark) and
   route to the home dashboard. Contacts permission is deferred to the income
   tab with its own *why* line ("to name who sends you money — matched on your
   phone only").

### E. Error / empty / offline system

1. **Build a shared `StateMessage` widget** (icon + title + explanation +
   action button) used by all screens; replace the current plain
   `ErrorState`/`EmptyState`.
2. **Error states**: muted red card, human message ("We couldn't load your
   transactions"), and a working **Retry** that re-fires the bloc; never show
   raw exception text (currently `InsightsError(e.toString())` renders raw
   strings).
3. **Empty states**: explain *why* + next step. E.g. income tab empty →
   "No income recorded yet — money sent to you will appear here" + "sync now".
4. **Offline detection**: connectivity_plus is already a dependency. Show a
   slim banner when offline ("You're offline — showing last synced data") and
   keep the last-loaded state on screen rather than erroring.

## 3. Suggested build order (small wins first)

1. `ShimmerSkeleton` + apply to home/insights loading (A)
2. Press states + haptics + AnimatedSwitcher tab transitions (B)
3. Frosted dock nav bar via BackdropFilter (C1) — highest visual impact
4. Shared StateMessage + replace ErrorState/EmptyState + hide raw errors (E)
5. Onboarding walkthrough + permission *why* lines (D)
6. Offline banner with connectivity_plus (E4)
7. Micro-interaction polish: label-save checkmark, MAB zone transitions,
   refresh toast (B)

## Sources

- Bill Chung, "Everything you need to know about skeleton screens", UX
  Collective (2018) — original skeleton research, shimmer-vs-pulse findings.
- NN/g, "Skeleton Screens" (2023); "Liquid Glass Is Cracked, and Usability
  Suffers in iOS 26" (2025); "Empty States in Complex Applications" (2021).
- 42Flows, "Micro-Interactions in Banking Apps" (2025) — trust/feedback cycle.
- Muzli / Marvel / IXDF micro-interaction literature.
- Incognia Friction Index + Fenergo 2025 + Signicat (via UserPilot,
  "Best Fintech Onboarding", 2026; Eleken, "Fintech Onboarding", 2025).
- Apple, "Liquid Glass" design docs (WWDC 2025); Design Monks,
  "Liquid Glass vs Glassmorphism" (2026) — glass as premium accent.
