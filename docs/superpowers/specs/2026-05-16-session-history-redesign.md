# Session History Redesign

**Date:** 2026-05-16  
**Scope:** `session_history_screen.dart`, `session_detail_screen.dart`, `sets_dao.dart`, `sessions_dao.dart`, new providers

---

## Overview

Two screens redesigned:

1. **Session History List** — each session tile expands to a two-row card showing volume, set count, avg RPE, volume delta vs previous same-named workout, and a PR chip for sessions that hit a new all-time record.
2. **Session Detail** — adds a stats header (total volume, sets, avg RPE, top weight, PR count, exercise count) above the exercise/set list. Sets are read-only by default; long-pressing a set reveals inline **Edit** and **Delete** buttons. Tapping Edit opens a modal bottom sheet with weight, reps, RPE, and notes fields. Saving silently recalculates PRs.

---

## Change 1 — Session History List

### Tile layout

**Before:** Single row — workout name, date string, program + week subtitle.

**After:** Two-row card.

**Row 1 (top):**
- **Date badge** (left): rounded square showing day number + 3-letter day name. Indigo tint for the most recent session; dim white for older ones.
- **Session name** (center): 14px w700, ellipsis overflow.
- **Week/program meta** (below name): 10px, dim.
- **PR chip** (right, only if session has ≥1 PR set): `🏆 N PRs`, indigo tint.

**Row 2 (bottom):** dark `rgba(0,0,0,0.18)` strip with 4 evenly-spaced stat columns separated by 1px dividers:

| Stat | Value | Note |
|---|---|---|
| VOL kg | `totalVolume` formatted with commas | + delta badge (↑/↓%) below if previous same-workout exists |
| SETS | `setCount` | always shown |
| DURATION | — | **omitted** — not tracked in DB |
| AVG RPE | `avgRpe` rounded to 1dp | omitted column if no RPE logged in this session |

**Volume delta:** compares `totalVolume` of this session against the most recent prior session with the same `workoutName`. Shown as `↑7%` (green) or `↓2%` (red) directly below the VOL value. Omitted if no prior session with the same name exists.

**PR detection:** a session "has PRs" if any of its sets has `weight_kg == currentPRForExercise`. PR count = number of distinct exercises in the session where this is true.

### Week grouping

Unchanged — sessions remain grouped by ISO week with a `WEEK LABEL` header above each group.

### Swipe to delete

Unchanged — existing swipe-left to delete session behaviour is preserved.

---

## Change 2 — Session Detail

### Stats header

Placed above the exercise list. Contains:

- **Featured stat box** (full width): total volume (kg) in large text + "↑ +N kg vs last {workoutName}" delta below. PR badge on the right if ≥1 PR exists.
- **Grid of 5 smaller boxes** (3-column): Sets · Avg RPE · Top Weight · Exercises · (empty if odd count).

Stats are computed from the loaded sets in Dart — no extra DB queries beyond what already loads the sets.

**Hint text:** `"Long-press any set to edit or delete"` shown between the stats grid and the first exercise block. Dim, small text.

### Long-press to edit/delete

State: `int? _pressedSetId` on the screen widget. Default null (nothing pressed).

- **Long-press** a set row → `setState(() => _pressedSetId = set.id)`. The row gets an indigo tint background and the weight/reps text shrinks to make room for two action buttons on the right: `Edit` (indigo) and `Delete` (red).
- Tapping anywhere outside (via `GestureDetector` wrapping the whole body) clears `_pressedSetId`.
- **Edit** → opens edit sheet (see below).
- **Delete** → shows `AlertDialog` for confirmation → on confirm, calls `deleteSet(id)` → invalidates PRs.

### Reactivity

Session detail currently loads sets once on init (`Future`). Replace with a `StreamProvider` or `ref.watch` on a new `setsForSessionProvider(sessionId)` so edits reflect immediately without requiring a reload.

### Edit Set Bottom Sheet

Triggered by tapping Edit on a long-pressed set. Uses `showModalBottomSheet(isScrollControlled: true, ...)`.

**Sheet content (top to bottom):**
1. Drag handle
2. Title: `"Edit Set · {exerciseName}"`, subtitle: `"Set {n} · {dateFormatted}"`
3. Divider
4. **Weight row** (hidden for timed exercises): label `WEIGHT`, `−` button, number display, `+` button, `kg` unit. Stepper of 0.5 kg increments.
5. **Reps row** (hidden for timed exercises): label `REPS`, `−` / `+` stepper, integer.  
   **Duration row** (shown instead for timed exercises): label `DURATION`, `−` / `+` stepper in 5-second increments, formatted as `m:ss`.
6. **RPE row**: label `RPE`, slider from 6.0 to 10.0 in 0.5 steps, current value shown right-aligned in amber. Optional — pre-filled from existing RPE or 0 (no RPE).
7. **Notes field**: multi-line `TextField`, max 4 lines, pre-filled from existing notes.
8. **Save button**: full-width `FilledButton`, label `"Save"`. Disabled if weight ≤ 0 or reps ≤ 0 (for weighted). On tap: calls `updateSet(...)`, invalidates `personalRecordsProvider`, dismisses sheet.
9. Bottom safe area padding.

RPE of exactly 0 is treated as "not set" and saved as `null`.

---

## Change 3 — DAO & Provider additions

### `sets_dao.dart`

Add:

```dart
// Reactive stream of sets for a session, ordered by exerciseId then setNumber
Stream<List<WorkoutSet>> watchSetsForSession(int sessionId);

// Update a single set
Future<bool> updateSet(WorkoutSetsCompanion entry);

// Delete a single set by id
Future<int> deleteSet(int id);

// Batch volume/count/RPE stats for all sessions in one query
Future<Map<int, SessionSetStats>> getAllSessionStats();
```

`SessionSetStats` is a plain Dart class (not a Drift table):
```dart
class SessionSetStats {
  final int sessionId;
  final double totalVolume;   // SUM(weight_kg * reps)
  final int setCount;
  final double? avgRpe;       // null if no RPE logged
  final double topWeight;     // MAX(weight_kg)
  final int exerciseCount;    // COUNT(DISTINCT exercise_id)
}
```

`getAllSessionStats()` runs a single SQL query:
```sql
SELECT 
  session_id,
  SUM(weight_kg * reps) as total_volume,
  COUNT(*) as set_count,
  AVG(rpe) as avg_rpe,
  MAX(weight_kg) as top_weight,
  COUNT(DISTINCT exercise_id) as exercise_count
FROM workout_sets
GROUP BY session_id
```

### New providers

In `lib/providers/session_providers.dart`:

```dart
// Per-session set stream (used by session detail for reactivity)
final setsForSessionProvider = StreamProvider.family<List<WorkoutSet>, int>(
  (ref, sessionId) => ref.watch(databaseProvider).setsDao.watchSetsForSession(sessionId),
);

// Batch stats for all sessions (used by history list)
final allSessionStatsProvider = FutureProvider<Map<int, SessionSetStats>>(
  (ref) => ref.watch(databaseProvider).setsDao.getAllSessionStats(),
);
```

`allSessionStatsProvider` is invalidated after any set edit or delete.

---

## PR Recalculation

PRs are computed on-the-fly from `MAX(weight_kg)` in the sets table. No stored PR value exists. After editing or deleting a set:

```dart
ref.invalidate(personalRecordsProvider);
ref.invalidate(allSessionStatsProvider);
// Optionally: ref.invalidate(strengthHistoryProvider(exerciseId));
```

The next read of any PR-related provider will recompute from the updated sets table automatically.

---

## Files Changed

| File | Change |
|---|---|
| `lib/database/daos/sets_dao.dart` | Add `watchSetsForSession`, `updateSet`, `deleteSet`, `getAllSessionStats`, `SessionSetStats` class |
| `lib/providers/session_providers.dart` | Add `setsForSessionProvider`, `allSessionStatsProvider` |
| `lib/screens/history/session_history_screen.dart` | Full tile redesign with stats row |
| `lib/screens/history/session_detail_screen.dart` | Stats header, long-press edit, reactive sets, edit bottom sheet |

---

## Out of Scope

- Session duration (not stored in DB — requires active session changes)
- Exercise history per-exercise screen (separate feature, tackled next)
- Adding new sets to a completed session
- Reordering sets
- Editing session name or date
