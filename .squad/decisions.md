# Squad Decisions

## Active Decisions

### 2026-09-04: Finish workout safeguard specified
**By:** Lead
**What:** Authored `specs/001-finish-workout-confirmation/spec.md` for the approved full-scope safeguard: de-emphasize the finish action, require a Review & Finish summary, and show an incomplete-only confirmation with Keep going and Finish anyway options.
**Why:** Finishing must be deliberate to prevent accidental premature completions, while Coach's domain rule requires legitimate early finishes to remain allowed and skipped work to count as resolved.

### 2026-09-04T18:00:26+02:00: Circuit active-session feature parity
**By:** Flutter, Tester, Tarek Kandil
**What:** Circuit exercise cards in active sessions must support logged-round editing, richer `ExerciseSwapSheet`-based swaps, remove-from-circuit, and circuit-level Add, Skip, and Remove controls; whole-circuit swap remains supported.
**Why:** Circuit logging should match non-circuit active-session capabilities, and regression tests now cover removal positions, swap variations, edit-save behavior, circuit-level add/skip/remove, and completion summaries after removal.

### 2026-09-04T18:00:26+02:00: Circuit skip scope
**By:** Tarek Kandil
**What:** Do not add per-exercise Skip inside circuits; use Remove from Circuit for an individual exercise and Skip Circuit for the entire circuit.
**Why:** The user confirmed per-exercise circuit skip is not wanted, and the existing individual remove plus circuit-level skip actions cover the intended workflow without extra UI.

### 2026-09-04: RIR effort UI replaces RPE direction
**By:** Designer
**What:** RIR effort input/display should order 0-to-5+ from hardest-left to easiest-right, use warm near-failure colors fading into indigo/cyan for easier effort, and label values explicitly as RIR to avoid RPE inversion confusion.
**Why:** RIR is inverted from RPE, so the UI must make lower values feel harder while preserving the app's Liquid Glass bottom-sheet and badge patterns for Flutter implementation.

### 2026-09-04T19:00:37+02:00: Adopted RIR over RPE via additive lossless migration
**By:** Coach, Flutter, Designer
**What:** Adopted RIR over RPE via additive lossless migration (schema v18): new rir/targetRir columns backfilled 10−rpe, RPE columns retained one release, dual-write + read-fallback; RIR is inverted (lower=harder).
**Why:** RIR communicates reps-in-reserve directly while preserving existing RPE data losslessly during the transition and keeping old builds/data paths compatible for one release.

### 2026-09-04: Body-weight coaching loop defaults
**By:** Coach
**What:** Body-weight coaching should use a 14-day default check-in cadence, convert target date into signed weekly pace with existing paceWarning guardrails, judge progress against trend-weight deltas with a ±0.25 kg/week tolerance, and nudge calories in 100–150 kcal/day steps rather than overreacting to one weigh-in.
**Why:** A two-week cadence balances adherence with scale-noise reduction, while small calorie nudges are practical and safer than aggressive recalculation. These defaults give Lead concrete model/spec values and Designer clear states for on-track, eat more, and eat less/tighten up guidance.

### 2026-09-04: Store one active weight goal plan on UserProfiles
**By:** Lead
**What:** Model the goal-driven body-weight loop as one active plan on the singleton `user_profiles` row via nullable additive columns, with bodyweight history remaining in `bodyweight_entries`.
**Why:** The app currently has one local user profile and no goal-history requirement. Extending `UserProfiles` keeps schema v19 non-destructive and lets Flutter wire profile calculations, providers, reminders, setup UI, and the home tile without introducing unnecessary table/DAO complexity.

### 2026-09-04: Weight goal workflow becomes a Weight Hub
**By:** Designer
**What:** Weight goal setup, weigh-in logging, trend/history, and on-track guidance should be consolidated into a GlassCard-based Weight Hub reached from a Home weight tile, instead of remaining as a basic settings-only Body Weight list.
**Why:** The feature needs one cohesive loop: glance on Home, act in the hub, adjust from weigh-ins, and review progress against the projected line. Keeping this workflow together improves discoverability and makes Coach guidance and Lead data requirements easier for Flutter to implement consistently.

### 2026-09-04T19:41:59+02:00: Weight Goal Coaching Loop (spec 002)
**By:** Coach, Lead, Designer, Flutter
**What:** Weight Goal Coaching Loop (spec 002): goal setup (desired weight + duration → calories/macros), weekly-default weigh-in reminders, on-track coaching (±150/±100 kcal, 2-check-in confirm), Weight Hub + home tile. Schema v19 additive on UserProfiles.
**Why:** Captures the cross-agent implementation direction for the new body-weight goal coaching loop so future Coach, Lead, Designer, and Flutter work share the same product, UX, and persistence contract.

#### 2026-09-04: Muscle taxonomy and weekly volume-report landmarks
**By:** Coach
**What:** Replace legacy broad tags with practical trainable muscles: Chest, Lats, Upper Back, Traps, Spinal Erectors, Front/Side/Rear Delts, Biceps, Triceps, Forearms, Quads, Hamstrings, Glutes, Adductors, Abductors, Hip Flexors, Calves, Abs, Obliques, and optional Neck. Treat Cardio/Full Body as non-muscle categories excluded from hypertrophy set landmarks. Weekly report should use effective hard sets per muscle: primary muscles receive 1.0 set credit, secondary muscles 0.5, adjusted down for explicitly easy 5+ RIR work; status comes from MV/MEV/MAV/MRV landmarks per muscle.
**Why:** Athletes need actionable muscle-level feedback without anatomical minutiae. Effective weekly sets align with hypertrophy programming practice better than tonnage alone, while preserving cardio separately prevents conditioning work from falsely inflating muscle-volume readiness.

#### 2026-09-04: Muscle taxonomy stores roles, not credit weights
**By:** Lead
**What:** The muscle-volume feature should add an explicit `role` column to `exercise_muscles` (`primary`/`secondary`) and compute weights in code, with `is_active` plus exercise review metadata to preserve legacy rows while excluding ambiguous/non-muscle mappings from reports.
**Why:** The spec is written around primary/secondary semantics, and code-owned role weights keep the DB stable if product wording or multipliers change. `is_active` and review metadata are necessary to meet the non-destructive migration requirement without allowing old broad tags such as Back, Shoulders, Core, Cardio, or Full Body to silently inflate weekly volume.

#### 2026-09-04: Intermediate muscle-volume landmark defaults
**By:** Lead
**What:** `specs/003-muscle-volume-report/spec.md` includes concrete Intermediate MV/MEV/MAV/MRV defaults for all 21 muscles, with Neck marked conservative/provisional.
**Why:** Planning and implementation need testable landmark numbers now; Coach can later revise the reference table without changing the approved simple 3-status report model.

#### 2026-09-04: Muscle volume report keeps three plain states
**By:** Designer
**What:** The weekly muscle-volume report should use a simple Home tile plus report UI with exactly three athlete-facing status labels: `Undertrained`, `Optimal`, and `Overtrained`. The main report should show only muscle name, this week's effective-set count, and one status pill; any range visual belongs only in optional progressive disclosure and must use plain `Low / Good / High` language.
**Why:** The user confirmed simplicity is the top UX constraint. The original three-status language supports fast training decisions while avoiding threshold jargon, and keeps the report consistent with the app's glanceable Liquid Glass Home-card patterns.

## Governance
- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
