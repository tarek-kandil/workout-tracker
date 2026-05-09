# Program Setup — WOD Card & Rest Redesign

**Date:** 2026-05-09  
**Scope:** `program_setup_screen.dart`, `wod_exercise_setup_screen.dart`, DB schema v12

---

## Overview

Three targeted changes to the program setup and exercise editing flow:

1. **WOD card interaction** — replace the "Edit Workouts" header button with a pencil indicator per card; two distinct tap zones on each card (name → rename, exercises → edit)
2. **Rest restructure** — split the single rest field into "between sets" and "after exercise", both defaulting to 90 s implicitly
3. **App bar cleanup** — remove the "Xs rest" WOD-level button from `WodExerciseSetupScreen`

---

## Change 1 — WOD Card Interaction

### Current behaviour
- A "✎ Edit Workouts" `TextButton.icon` in the program screen header navigates all cards to `WodExerciseSetupScreen`
- The entire `_WodTile` card is wrapped in an `InkWell` that also navigates to the exercise screen
- No per-card delete affordance in this view

### New behaviour
- Remove the "Edit Workouts" `TextButton.icon` from the header row in `_WodListState`
- Each `_WodTile` has **one pencil icon** (✎, `Icons.edit_outlined`) in the header row — a visual affordance that the card is editable; rendered as a plain `Icon`, no `onTap`, not wrapped in `IconButton`
- **Name zone** (the `Text(wod.name)` widget): tapping it enables in-place rename
  - `_WodTile` becomes `ConsumerStatefulWidget` with `_editing` bool and `_nameCtrl TextEditingController`
  - When `_editing = true`: replace `Text` with a transparent, borderless `TextField` (same font, same size, no fill, no border — just a faint indigo underline via `UnderlineInputBorder`)
  - Card border subtly highlights (`rgba(99,102,241,0.3)`) while editing
  - Confirm: `onSubmitted` or `onEditingComplete` → save to DB, `_editing = false`
  - Cancel: tap outside (handled via `FocusNode` `onUnfocus`)
  - Saves via `db.programsDao.updateWodTemplate(...)`, then `ref.invalidate(wodTemplatesForPhaseProvider(phaseId))`
- **Exercises zone** (the exercise list `Column` below the divider): wrapped in `GestureDetector` → navigates to `WodExerciseSetupScreen(wodTemplateId: wod.id)`
  - Subtle press feedback via `InkWell` with `borderRadius: BorderRadius.vertical(bottom: Radius.circular(18))`
- The drag handle (`ReorderableDragStartListener`) remains in the header row, unchanged

### Affected widget
`_WodTile` in `program_setup_screen.dart` — convert to `ConsumerStatefulWidget`.

---

## Change 2 — Rest Restructure

### Current behaviour
- `WodTemplate.restSeconds`: a WOD-level default rest shown in the app bar ("90s rest" button) in `WodExerciseSetupScreen`
- `WodTemplateExercise.restSeconds`: per-exercise override, labeled "REST AFTER THIS EXERCISE" in the edit dialog
- No "between sets" concept

### New behaviour
Two independent rest values per exercise, both optional (null = use 90 s default):

| Field | Meaning | Default |
|---|---|---|
| `restBetweenSetsSeconds` (new) | Rest between set 1 → set 2 of the same exercise | 90 s |
| `restSeconds` (existing, renamed in UI) | Rest after all sets done, before next exercise | 90 s |

**Edit dialog (`_EditExerciseDialog`):**
- Remove the single "REST AFTER THIS EXERCISE" `_RestStepper`
- Add two `_RestStepper` controls (standalone exercises only, not circuit exercises):
  - **"REST BETWEEN SETS"** — `_restBetweenSetsSeconds`, `allowZero: false`, default 90
  - **"REST AFTER EXERCISE"** — `_restAfterExerciseSeconds`, `allowZero: true`, default 90
- Both show current value; hint text "Default 90 s" when at default (optional, keeps UI lean)
- `_ExerciseConfig` gains `restBetweenSetsSeconds` field

**Tile display (`_StandaloneExerciseTile`):**
- If either rest value is overridden (≠ null and ≠ 90), show compact rest pill(s) in the meta row
- Format: `"2:00 sets"` and/or `"1:30 after"` using existing `_fmtSec`
- No pill shown when both are at the implicit default

### DB change
Schema version: **12**

```sql
ALTER TABLE wod_template_exercises
  ADD COLUMN rest_between_sets_seconds INTEGER;
```

Migration guard: `PRAGMA table_info` check before `addColumn`.  
`WodTemplateExercises` table class: add `IntColumn get restBetweenSetsSeconds => integer().nullable()();`  
Run `build_runner` after schema change.

---

## Change 3 — App Bar Cleanup

Remove the `TextButton.icon` ("⏱ Xs rest") action from the `AppBar` in `WodExerciseSetupScreen`.

- The `_editRestTime()` method and its dialog can be deleted
- The `_restSeconds` state variable is no longer needed at the WOD level in this screen
- `WodTemplate.restSeconds` column is kept in the DB (no migration needed to remove it); it is simply no longer surfaced in the UI

---

## Data Flow

```
_WodTile (program_setup_screen)
  name tap → TextField in-place → updateWodTemplate → invalidate provider
  exercises tap → push WodExerciseSetupScreen

WodExerciseSetupScreen
  _StandaloneExerciseTile → tune icon → _EditExerciseDialog
    _restBetweenSetsSeconds stepper → saved to wod_template_exercises.rest_between_sets_seconds
    _restAfterExerciseSeconds stepper → saved to wod_template_exercises.rest_seconds
```

---

## Files Changed

| File | Change |
|---|---|
| `lib/database/tables/wod_template_exercises_table.dart` | Add `restBetweenSetsSeconds` column |
| `lib/database/app_database.dart` | Bump schema to v12, add migration |
| `lib/screens/settings/program_setup_screen.dart` | `_WodTile` → `ConsumerStatefulWidget`, in-place rename, exercises zone tap, remove "Edit Workouts" button |
| `lib/screens/settings/wod_exercise_setup_screen.dart` | Remove app bar rest button + `_editRestTime`, split rest into two steppers in dialog, add rest pills to tile |

---

## Out of Scope

- Circuit rest fields (`restBetweenExercisesSeconds`, `restBetweenRoundsSeconds`) — already correctly split, no change
- Active session screen — rest timer reads `restSeconds`; `restBetweenSetsSeconds` will be wired in a future session screen update
- Program list screen — no changes
