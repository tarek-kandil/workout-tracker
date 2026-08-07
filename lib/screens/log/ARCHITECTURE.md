# Active Session (Log) — Feature Architecture

This folder implements the **live workout logging screen** (`ActiveSessionScreen`) —
the screen the user drives while performing a workout: logging sets, resting,
reordering exercises, swapping/adding exercises, and finishing the session.

It was refactored from a single 3,000-line file into a feature-first structure so
the UI (widgets) is cleanly separated from the screen's logic (the state class).

## Layout

```
lib/screens/log/
  active_session_screen.dart     # ConsumerStatefulWidget + state/logic + build() composition
  session_formatters.dart        # fmtW / fmtSec / fmtRpe — pure display formatters
  models/
    session_models.dart          # SetData, SessionItem, CardState (in-memory session state)
  audio/
    session_sounds.dart          # WAV tone generators for beeps/ticks/done cues
    session_sound_player.dart    # SessionSoundPlayer service (players + haptics + play* cues)
  widgets/                        # Presentational widgets (no business logic)
    session_common.dart          # Shared leaves: StatusBadge, ReadOnlyField, ActionTile,
                                  #   TimedSetInput, SuggestionBadge
    history_chip_row.dart        # "Last" / PR history chips + expandable last-session table
    set_row.dart                 # SetRowItem (per-set row) + SetRow (active editable stepper)
                                  #   + StepperField + StepBtn
    check_circle_button.dart     # Animated "mark set done" check button
    rpe_sheet.dart               # Optional RPE (rate of perceived exertion) picker sheet
    exercise_card.dart           # ExerciseCard — a single standalone exercise
    circuit_card.dart            # CircuitCard + CircuitExerciseSection + RoundRowItem
    config_stepper.dart          # ConfigStepper (+ _cfgBtn) used when adding an exercise
    exercise_library_sheet.dart  # ExerciseLibrarySheet — searchable exercise picker
    rest_pill.dart               # Floating rest-timer pill
    resume_prompt_overlay.dart   # ResumePromptOverlay (+ PromptAction) resume/restart/discard
    countdown_overlay.dart       # CountdownOverlay for circuit autopilot ("3…2…1")
```

## Responsibilities

### `active_session_screen.dart` — the only stateful/logic file
`_ActiveSessionScreenState` owns **all** session logic and mutable state. Its
methods are grouped by `// ──` banner comments:

- **State fields**: data maps (`_setData`, `_lastSets`, `_prData`, `_historyExpanded`),
  the mutable `_sessionItems` list, progress cursors (`_currentItemIdx`,
  `_currentSetIdx`, `_circuitExerciseIdx`), rest/exercise timers, audio players,
  circuit autopilot, and resume-prompt state.
- **Lifecycle / Load**: init, app-lifecycle handling, initial load + resume restore.
- **Done set / PR / RPE**: `_onDoneSet` advances the cursor, detects PRs, and opens
  the RPE sheet.
- **Rest / Exercise timers + Audio + Notification**: countdowns and sound cues.
- **Save / restore / Finish**: SharedPreferences autosave, resume, and persisting
  the finished session to the database.
- **Mutations**: skip, edit, reorder, remove, swap, and add exercises.
- **Action sheets**: bottom sheets that call into the mutations.
- **build()**: pure composition — wires the widgets in `widgets/` to state + callbacks.

Widgets never touch the state class directly; they communicate **only via
constructor parameters and callbacks** (e.g. `onDoneSet`, `onReorder`,
`onSetDataChanged`). This is what makes them independently testable and movable.

### `models/session_models.dart`
- `SetData` — the editable value for one set (weight, reps, duration, optional rpe).
- `SessionItem` — wraps a `WodItem` with per-session metadata (`id`, `skipped`,
  `isAdHoc`, `skippedSets`). `id` is a stable unique key used for
  `ReorderableListView` and is preserved across swaps.
- `CardState` — `active | completed | upcoming`, derived by `_cardStateFor(i)`.

## State management

- **Riverpod** (`ConsumerStatefulWidget`, `ref.read/watch`) for data/DI: database
  access and providers. Matches the rest of the app.
- **`setState`** for local, per-session UI state inside `_ActiveSessionScreenState`.

There is intentionally **no ViewModel/controller** — the logic lives in the state
class. This was a deliberate "no behavior change" refactor; extracting a controller
is a possible future step but was out of scope.

## Key invariants (read before editing reorder / completion logic)

- **Completion is index-based**: `_cardStateFor(i)` = `completed` if
  `_sessionItems[i].skipped` **or** `i < _currentItemIdx`; `active` if
  `i == _currentItemIdx`; else `upcoming`.
- **Reorder is drag-and-drop only** (there is no Move Up/Down). Completed/skipped
  cards render **without a drag handle** (`dragIndex: null`), so a done exercise
  cannot be dragged. `_onReorder` keeps `_currentItemIdx` fixed and clamps drops so
  the completed region (indices `< _currentItemIdx`) never changes — this prevents
  an exercise from being falsely marked done during a reorder.
- **Reorder is in-memory**: the reordered order is not restored after an app-kill
  resume (resume reapplies skip state by position). Changing this requires
  persisting item identity/order in `_saveProgress` / `_applyResumeData`.

## Conventions for extending this feature

- Add new presentational pieces as their own file under `widgets/`, with a **public**
  class (matches `screens/home/widgets/`). Keep single-use sub-widgets private in the
  same file.
- Widgets stay logic-free: pass data in, emit events via callbacks.
- New session logic goes into `_ActiveSessionScreenState`, under the appropriate
  `// ──` section, and is exposed to widgets through callbacks in `build()`.
- Reuse `session_formatters.dart` for number/time formatting; don't re-implement.
