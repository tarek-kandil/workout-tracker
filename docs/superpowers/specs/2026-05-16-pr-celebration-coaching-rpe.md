# PR Celebration + Coaching Notes & RPE

**Date:** 2026-05-16  
**Scope:** `active_session_screen.dart`, `app_database.dart` (schema v14), `wod_template_exercises` table, `_SetData` model, `celebration_overlay.dart`

---

## Overview

Two features added to the active session screen:

1. **PR Celebration Overlay** — when a set beats the all-time record for an exercise (new max weight, or more reps at the current PR weight), a full-screen overlay card pops up to celebrate.
2. **Coaching Notes + RPE** — a ℹ icon on the exercise card opens the coach's notes in a bottom sheet; target RPE is shown as an amber badge next to the set label; after every "Done Set" a small RPE sheet slides up so the user can optionally log their effort.

---

## Feature 1 — PR Celebration Overlay

### Triggers

Checked immediately when the user taps "Done Set":

| Trigger | Condition |
|---|---|
| New max weight | `loggedWeight > (_prData[exerciseId] ?? 0)` |
| More reps at PR weight | `loggedWeight == _prData[exerciseId] && loggedReps > _bestRepsAtPrWeight(exerciseId)` |

`_bestRepsAtPrWeight(exerciseId)` returns the highest rep count from `_lastSets[exerciseId]` where `weightKg == _prData[exerciseId]`. Returns 0 if no history.

Only fires once per exercise per session. After the first PR for an exercise, update `_prData[exerciseId]` to the new weight so subsequent sets are measured against the new bar.

### UI

Full-screen overlay using `showGeneralDialog` (or `Navigator.push` with a transparent route). Matches Option B from the mockup:

- **Backdrop:** `rgba(0,0,0,0.72)` + `BackdropFilter(blur: 6)`
- **Card:** `LiquidGlassContainer` variant — `#1e1b4b→#1a1a2e` gradient background, indigo border, 20px radius, 200px wide
  - Radial gold glow behind trophy: `rgba(251,191,36,0.25)` radial gradient
  - Trophy emoji 36px
  - `"NEW PR!"` — 16px w800, gold `#FFD700`
  - New weight — 26px w800, white
  - Delta line — `"↑ +2.5 kg from 80 kg"` — 10px, dim white (omitted if no prior PR)
  - Exercise name + reps — 10px, dim white
  - Spacer
  - Dismiss button — `FilledButton` with label `"Crush it! 💪"`, indigo

- **Animation:** `ScaleTransition` from 0.4 → 1.0 with `ElasticOutCurve(0.7)` over 500ms
- **Auto-dismiss:** `Timer(Duration(seconds: 3), () => Navigator.pop(...))` — cancelled if user taps the button first
- **Sound:** play 3 ascending beeps in sequence using `_makeBeepWav`: 660 Hz / 150ms, then 880 Hz / 150ms, then 1100 Hz / 200ms — each triggered via `Future.delayed(Duration(milliseconds: N))` after the overlay appears. Reuses the existing `_beepPlayer` instance.

### Sequence after Done Set

```
Done Set tapped
  → _logCurrentSet() writes to DB
  → _checkAndShowPr() — if PR: show overlay, await dismiss
  → _showRpeSheet() — always, await dismiss/skip
  → _advanceSet() — move to next set / start rest timer
```

The rest timer does **not** start until both sheets are dismissed.

---

## Feature 2 — Coaching Notes + RPE

### 2a — ℹ Coaching Notes Icon

**Visibility:** Only rendered when `entry.exercise.notes` is non-null and non-empty.

**Placement:** In `_ExerciseCard` header row, right column. The ℹ icon is placed to the **left** of the existing `more_horiz` overflow button, both on the same `Row`. The existing layout is unchanged; ℹ is simply prepended when notes are present.

**Interaction:** `IconButton` with `Icons.info_outline_rounded`, size 18, `Colors.white38`. Taps call `showModalBottomSheet(isScrollControlled: true, ...)`.

**Bottom sheet content (top to bottom):**
1. Drag handle (32×3px, `Colors.white24`, centered)
2. Exercise name — 14px w800
3. Subtitle: `"Coaching Notes"` — 10px, dim
4. Divider
5. Notes text in a frosted `Container` — `rgba(255,255,255,0.05)` bg, 1px border, 10px radius, 9px text, 1.5 line-height
6. If `te.rpeGoal != null`: bottom row with `"Target RPE"` label (left, dim) and `rpeGoal` value (right, 18px w800, amber `#FBBF24`)
7. Bottom safe-area padding

### 2b — Target RPE Badge

**Visibility:** Only shown when `te.rpeGoal != null`.

**Placement:** In `_SetRowItem` (or the active set section of `_ExerciseCard`), on the same row as the `"Set N / N"` label, right-aligned.

**Style:** Amber pill — `rgba(251,191,36,0.1)` bg, `rgba(251,191,36,0.3)` border, `#FBBF24` text, 8px w700, text `"Target RPE {n}"`.

Only shown for the **active** set row, not completed/skipped sets.

### 2c — Post-Set RPE Sheet

**Trigger:** After every "Done Set" tap, after any PR overlay is dismissed.

**Implementation:** `showModalBottomSheet(isScrollControlled: true, isDismissible: true, enableDrag: true, ...)` — user can swipe down or tap the scrim to skip with no RPE logged.

**Sheet content (top to bottom):**
1. Drag handle
2. Title: `"How hard was that?"` — 12px w800
3. Subtitle: `"Set {n} · {exerciseName} · optional"` — 9px, dim
4. Divider
5. Dot grid — 9 tappable dots for RPE 6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0
   - Each dot: amber when selected, dim otherwise
   - Dot shows the numeric value (e.g. "8.5")
   - Row below selected dot: short description (`"2 reps left"`, `"Near failure"`, etc.)
6. Bottom safe-area padding

**RPE descriptions:**

| RPE | Description |
|---|---|
| 6.0 | Very easy |
| 6.5 | Easy |
| 7.0 | Moderate |
| 7.5 | Somewhat hard |
| 8.0 | Hard, 2–3 reps left |
| 8.5 | Very hard, 1–2 reps left |
| 9.0 | 1 rep left |
| 9.5 | Could not do more reps |
| 10.0 | Max effort, failure |

**Interaction:** Tap a dot → RPE value stored in `_SetData.rpe` for that set index → sheet auto-dismisses after 300ms. Swipe-down / tap-scrim → `rpe = null`, sheet dismissed.

**Storing RPE:** `_SetData` gets `double? rpe`. When `_logCurrentSet()` writes the `WorkoutSetsCompanion`, it includes `Value(setData.rpe)` for the `rpe` column (column already exists in schema).

---

## Schema Change — `rpe_goal` column

Add nullable `REAL` column `rpe_goal` to `wod_template_exercises`.

**Migration:** schema version 14. Guard with `PRAGMA table_info` check (existing pattern in this codebase).

```sql
ALTER TABLE wod_template_exercises ADD COLUMN rpe_goal REAL;
```

**Drift entity update:** Add `RealColumn get rpeGoal => real().nullable()();` to `WodTemplateExercises` table class.

**Program setup UI:** Out of scope for this spec. The column will exist but the setup screen will not yet expose it. Target RPE badge and coaching notes sheet will only show if the value is non-null, so existing programs are unaffected.

---

## Files Changed

| File | Change |
|---|---|
| `lib/database/app_database.dart` | Add `rpeGoal` column to `WodTemplateExercises`; bump schema to v14; add migration |
| `lib/screens/log/active_session_screen.dart` | Add `rpe` to `_SetData`; add `_checkAndShowPr()`; add `_showRpeSheet()`; add `_bestRepsAtPrWeight()`; update `_logCurrentSet()` to include RPE; add ℹ icon to `_ExerciseCard`; add target RPE badge to active set row |
| `lib/widgets/celebration_overlay.dart` | Add `showPrOverlay(context, exerciseName, newWeightKg, oldWeightKg?, reps)` function |

---

## Out of Scope

- Per-set target RPE configuration in program setup (future)
- Warmup set flag (future)
- RPE logging for timed exercises (timed sets skip the RPE sheet)
- Editing RPE after the session (already handled by session detail edit sheet)
