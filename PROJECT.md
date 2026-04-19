# Workout Tracker — Project Reference

A Flutter app for structured, progressive-overload training. Dark "Liquid Glass" aesthetic (deep midnight `#0F172A`, soft indigo `#818CF8`, electric sky `#38BDF8`). Built with Drift (SQLite), Riverpod, and Material 3.

---

## Navigation

Four-tab bottom nav shell (`ShellScreen`):

| Tab | Screen |
|-----|--------|
| Home | Dashboard with cards |
| History | Session log |
| Records | Personal records |
| Profile | Settings |

---

## Database Schema (Drift / SQLite)

### `programs`
| Column | Type | Notes |
|--------|------|-------|
| id | int PK | |
| name | text | |
| status | int | 0=active, 1=completed, 2=draft |
| notes | text? | |

### `program_phases`
Phases within a program (e.g. Hypertrophy, Strength). Each has a `weekCount`.

### `wod_templates`
One WOD (Workout of the Day) template per session slot in a phase.
| Column | Type | Notes |
|--------|------|-------|
| phaseId | int FK | → program_phases |
| wodNumber | int | order within phase |
| name | text | |
| restSeconds | int | default 90 — drives rest timer |

### `wod_template_exercises`
Exercises within a WOD template.
| Column | Type | Notes |
|--------|------|-------|
| wodTemplateId | int FK | |
| exerciseId | int FK | |
| sortOrder | int | |
| targetSets | int | |
| repRangeMin | int | reps, or seconds for timed exercises |
| repRangeMax | int | reps, or seconds for timed exercises |

### `exercises`
Global exercise library, seeded on first launch.
| Column | Type | Notes |
|--------|------|-------|
| name | text | |
| category | text | Push/Pull/Legs/Core/Cardio/Other |
| notes | text? | |
| isTimed | bool | false = weight+reps, true = duration |

Default seeded exercises: Bench Press, Incline Bench Press, OHP, Deadlift, Squat, Pull-ups, Lat Pulldown, Barbell Row, Leg Press, RDL, Lunges, Plank, Ab Wheel, and more (~26 total).

### `workout_sessions`
Logged workout instances.
| Column | Type | Notes |
|--------|------|-------|
| date | dateTime | |
| workoutName | text | auto-filled from WOD template |
| wodTemplateId | int? FK | null for ad-hoc sessions |
| weekNumber | int? | calendar week within the program |

### `workout_sets`
Individual sets within a session.
| Column | Type | Notes |
|--------|------|-------|
| sessionId | int FK | |
| exerciseId | int FK | |
| setNumber | int | |
| reps | int | 0 for timed exercises |
| weightKg | real | 0 for timed exercises |
| durationSeconds | int? | only set for timed exercises |
| rpe | real? | 6.0–10.0, optional |

### `daily_tasks` / `daily_task_completions`
User-defined daily habits tracked from the home screen.

### `bodyweight`
Bodyweight log entries (date + kg).

---

## Key Screens

### Home (`home_screen.dart`)
Cards shown when a program is active:
- **ActiveProgramCard** — program name + phase progress
- **NextWorkoutCard** — upcoming WOD with exercise list; detects saved progress and shows Resume / Restart / Discard buttons
- **BodyweightCard** — log + sparkline
- **StreakCard** — workout streak counter
- **DailyTaskHomeCard** — one card per enabled daily task

When no program is set: prompt to create one + bodyweight card + daily tasks.

### Active Session (`active_session_screen.dart`)
Step-by-step workout flow:
- One **current exercise card** at the top (with left accent border)
- **Completed exercises** section below (green tiles)
- **Up Next** section (dimmed tiles)
- Progress bar in AppBar showing exercise N of M

**Per-set input:**
- Weighted: weight stepper (±2.5 kg) + reps stepper (±1), tap value to type
- Timed: Start Timer → running stopwatch → Stop → auto-advances after 600 ms

**Rest timer overlay** (full-screen, dark):
- Circular countdown arc
- Duration from `wod_template.restSeconds` (default 90 s)
- Skip button; beep + triple haptic when timer reaches 0
- Audio: WAV generated in-memory (880 Hz, 350 ms, with fade envelope) via `audioplayers`

**Session persistence:**
- Progress auto-saved to `SharedPreferences` after every set (`workout_progress_<wodId>`)
- On re-open: Resume / Restart / Discard overlay
- Home card also detects saved progress before navigating in

**Finish:** logs all filled sets to DB, skips unfilled sets, shows celebration overlay, pops back.

### Program Setup (`program_setup_screen.dart`)
Multi-step wizard: program name → phases (name + week count) → review.

### WOD Setup (`wod_setup_screen.dart`)
Edit WOD name, rest time, reorder/add/remove WODs in a phase.

### WOD Exercise Setup (`wod_exercise_setup_screen.dart`)
- Add exercises from library (or create new inline)
- Edit: sets, rep range / time range, notes
- Toggle `isTimed` per exercise — persisted back to the exercise library
- Display shows "3 sets · 0:30–1:00" for timed, "3 sets · 6–12 reps" for weighted

### Exercise Library (`exercise_library_screen.dart`)
Browse/edit all exercises. Shows `isTimed` badge.

### Session History (`session_history_screen.dart` + `session_detail_screen.dart`)
List of past sessions. Detail screen shows sets grouped by exercise; timed exercises show duration instead of weight×reps.

### Personal Records (`personal_records_screen.dart`)
Best weight (weighted) or longest duration (timed) per exercise.

### Exercise History (`exercise_history_screen.dart`)
Per-exercise history chart and set log.

### Daily Tasks (`daily_tasks_screen.dart`)
Create/toggle daily habit tasks shown on home.

### Bodyweight (`bodyweight_screen.dart`)
Log and chart bodyweight over time.

---

## Providers (Riverpod)

| Provider | What it does |
|----------|-------------|
| `databaseProvider` | Singleton `AppDatabase` |
| `activeProgramProvider` | Currently active program + phases |
| `nextWodProvider` | Computes next WOD to do based on session history |
| `exercisesProvider` | Full exercise list |
| `dailyTasksProvider` | All daily tasks |
| `sessionProviders` | Session list / detail |
| `shellIndexProvider` | Selected bottom-nav tab index |

---

## Services

- **NotificationService** — `flutter_local_notifications` + `timezone`; initialised at startup

---

## UI System

- **GlassBackground** — animated blobs that BackdropFilter blurs
- **LiquidGlassContainer** — frosted glass card (blur + tint + border)
- **GlassRoute** — custom page route with glass transition
- **VibrantText** — high-contrast text widget
- **CelebrationOverlay** — shown after finishing a workout

---

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `drift` + `sqlite3_flutter_libs` | Local SQLite database with code-gen |
| `flutter_riverpod` + `riverpod_annotation` | State management |
| `shared_preferences` | Session progress persistence |
| `audioplayers` | Rest timer end beep |
| `flutter_local_notifications` | Push notifications |
| `fl_chart` | Charts (bodyweight, exercise history) |
| `intl` | Date formatting |

---

## Known Patterns & Conventions

- DB schema changes require re-running `dart run build_runner build` to regenerate `.g.dart` files
- `repRangeMin` / `repRangeMax` store **seconds** (not reps) when `exercise.isTimed = true`
- Timed sets store `durationSeconds`; `reps` and `weightKg` are saved as 0
- `weekNumber` on sessions is the calendar week within the program (used to determine which WOD comes next)
- `restSeconds` lives on the WOD template — changing it affects all future sessions for that WOD
