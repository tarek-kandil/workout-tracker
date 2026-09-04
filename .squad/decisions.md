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

## Governance
- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction
