# Active Session Screen — UX Redesign

**Date:** 2026-05-05  
**Status:** Approved

## Problem

The current active session screen is too rigid:
- Only the current exercise is expanded; completed and upcoming exercises are minimised or hidden
- Text is small and the layout is cramped
- No way to swap a broken/busy machine's exercise on the spot
- No way to reorder exercises mid-workout
- No way to skip a set or an entire exercise
- No way to add an ad-hoc exercise not in the program
- Circuits show no per-exercise detail for upcoming exercises
- History is a single compressed line (`80×8 · 82.5×8`) — individual sets are not visible at a glance

## Design

### 1. Overall Layout — Flat scrollable list

Replace the current expanded-card + two minimised sections with a single continuous scrollable list. Every exercise card is always fully expanded.

**Card states:**
| State | Visual treatment |
|---|---|
| Current | Accent border glow + `▶ NOW` badge |
| Completed | Green tint + `✓ DONE` badge; logged sets shown (dimmed) |
| Upcoming | ~75% opacity; last session sets visible as read-only rows |

**Between every card** (including before the first and after the last): a small `＋ add exercise` inline button.

The app bar subtitle changes to reflect the active exercise + set progress (e.g. "Bench Press · Set 2 of 4"). The linear progress bar at the top continues to reflect overall WOD completion.

### 2. Set Rows

Every exercise card shows all sets as individual rows. For a 4-set exercise:

```
Set 1  ✓  [ 80 kg ]  [ 9 reps ]      ← completed, dimmed
Set 2  ○  [ 80 kg ]  [ 9 reps ]      ← active, purple highlight
Set 3  ○  [  —   ]  [   —   ]        ← future, very dim
Set 4  ○  [  —   ]  [   —   ]        ← future, very dim
```

- Active set fields use the existing stepper (+/−) and tap-to-type interaction
- Weight pre-fills from suggestion (same logic as today)
- `Done Set` check-circle button appears below the active set row (same animated check-circle as today)
- **Skip a set:** long-press any future set row → context menu with "Skip this set". Skipped sets are marked with a strikethrough label and do not get saved to the DB.

**Circuits:** use "Round 1 / Round 2 / Round 3" row labels instead of "Set N". Each exercise within the circuit has its own set of round rows. Layout within the circuit card:
- Teal-accented circuit header (name + rounds + rest info)
- Each exercise as a sub-section inside the circuit card
- Active exercise within the circuit gets the `▶ NOW` badge
- Done rounds are dimmed with ✓; future rounds are very dim

### 3. History Chip (inline expandable)

Directly below the exercise name + meta line, two chips:
- **`Last ▾`** — tap to expand an inline mini-table showing all sets from the most recent session for this exercise (weight × reps per row). Tap again to collapse.
- **`PR X kg`** (or `PR X:XX` for timed) — display only, no interaction.

The inline expanded table is read-only. It does not replace or scroll away from the set input rows.

### 4. Exercise Actions (`···` menu)

A `···` icon in the top-right of every exercise card. Tapping opens a bottom action sheet:

| Action | Behaviour |
|---|---|
| **Swap Exercise** | Opens exercise library search. User searches by name. If not found, "Create new exercise" option creates it in the library and inserts it. Replaces this card for this session only — the program is not modified. |
| **Move Up** | Swaps this exercise with the one above it in the list |
| **Move Down** | Swaps this exercise with the one below it |
| **Skip Exercise** | Marks the whole exercise as skipped (no sets saved); advances focus to the next exercise |
| **Remove** | Only available for ad-hoc exercises added during the session. Removes the card. |

"Swap" and "Skip" are available on all exercises. "Remove" is only available on ad-hoc cards.

### 5. Add Exercise (`＋ add exercise`)

Tapping the `＋ add exercise` button between cards:
1. Opens an exercise library search sheet (same library used elsewhere in the app)
2. If the exercise is not found: **"Create new exercise"** option — user enters name, selects type (weighted / timed / bodyweight), saves it to the library, and it is inserted
3. After selecting an exercise: a small config step lets the user set sets + rep range (pre-filled from library defaults if available, otherwise sensible defaults: 3 sets, 8–12 reps)
4. The card is inserted at the chosen position with an `＋ added` badge
5. Ad-hoc cards can be removed via `···` → Remove

### 6. Session State & Persistence

- `_currentItemIdx` / `_currentSetIdx` / `_circuitExerciseIdx` continue to drive which set is "active"
- Reordering and skipping mutate a local mutable copy of the items list (derived from `widget.result.items` at load time), not the DB
- Ad-hoc exercises are appended to the local items list only — they are saved to `workout_sets` on finish like any other exercise, but they do not modify `wod_template_exercises`
- Progress save/restore (`SharedPreferences`) must persist the mutable items order and any ad-hoc exercise IDs
- Skipped sets are not written to the DB on finish

### 7. Text Size

Increase base font sizes throughout the active session screen:
- Exercise name in current card: `titleLarge` (was `titleMedium`)
- Set value fields: `15px` (was `14px`)
- Set number labels, meta text: `11px` (was `9–10px`)
- History chip and inline table: `11px`

The screen is scrollable, so content does not need to fit in one viewport.

## Out of Scope

- Modifying the underlying program or WOD template mid-session
- Persistent reordering across sessions
- Multi-session history beyond "last session" in the inline chip (full history remains in the Records screen)
