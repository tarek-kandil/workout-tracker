# Exercise Library — Muscle Groups Redesign

**Date:** 2026-05-10
**Scope:** `exercise_library_screen.dart`, `constants.dart`, `exercises_table.dart`, `app_database.dart`, new `exercise_muscles_table.dart`

---

## Overview

Three changes to the exercise library:

1. **Card redesign** — bigger cards, pencil icon removed
2. **Muscle groups** — replace the single free-text `category` field with a structured multi-muscle system (first = primary, rest = secondary), backed by a new `exercise_muscles` table
3. **Expanded library** — seed data grows from 26 → 68 exercises, all with expert muscle-group assignments

---

## Change 1 — Card Redesign

### Current
- `Container` with `padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10)`, `borderRadius: 12`
- Row: `[name, timerIcon?, pencilIcon]`

### New
- `padding: EdgeInsets.fromLTRB(14, 13, 14, 11)`, `borderRadius: 16`, border `1.5px`
- Remove pencil `Icon` entirely
- Two-row layout:
  - Row 1: exercise name (15 px, w700) + optional `TIMED` chip (indigo, 10 px)
  - Row 2: primary muscle chip (indigo, `muscle-primary` style) + secondary muscle chips (dim, `muscle-secondary` style)
  - If no muscles assigned: Row 2 omitted
- Tapping the card still opens the edit dialog (no change to tap logic)

**Chip styles:**
```dart
// Primary
Container(
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(
    color: Color(0xFF6366F1).withValues(alpha: 0.15),
    borderRadius: BorderRadius.circular(7),
    border: Border.all(color: Color(0xFF6366F1).withValues(alpha: 0.28)),
  ),
  child: Text(muscle, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF818CF8))),
)

// Secondary
Container(
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(
    color: Colors.white.withValues(alpha: 0.05),
    borderRadius: BorderRadius.circular(7),
    border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
  ),
  child: Text(muscle, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.38))),
)
```

---

## Change 2 — Muscle Groups

### Predefined muscle list (immutable, hardcoded)

```dart
const List<String> kMuscleGroups = [
  'Chest', 'Back', 'Shoulders', 'Triceps', 'Biceps',
  'Front Delt', 'Rear Delt', 'Quads', 'Hamstrings',
  'Glutes', 'Core', 'Calves', 'Full Body', 'Cardio',
];
```

### DB schema — v13

New table `exercise_muscles`:

```dart
class ExerciseMuscles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.cascade)();
  TextColumn get muscle => text()();
  IntColumn get sortOrder => integer()();
}
```

Migration (PRAGMA-guarded):
```dart
if (from < 13) {
  final tables = await customSelect('SELECT name FROM sqlite_master WHERE type="table"').get();
  final exists = tables.any((r) => r.read<String>('name') == 'exercise_muscles');
  if (!exists) {
    await m.createTable(exerciseMuscles);
  }
}
```

The existing `category` column on `exercises` is **kept in the DB** but no longer shown in the UI. No migration needed to remove it.

### Grouping on screen

The list screen groups exercises by their **primary muscle** (`sort_order = 0`). Exercises with no muscle assignments appear at the bottom under "Other".

The DAO joins `exercise_muscles` where `sort_order = 0` to get each exercise's primary muscle, then the screen groups in Dart.

### Edit dialog — muscle picker

Replace the "Category" `Autocomplete` field with a muscle-group chip grid:

- Display all 14 muscles from `kMuscleGroups` as tappable chips
- **First tap** = adds to selection (appears indigo if it's first selected, else dim)
- **Subsequent taps on selected** = removes from selection; if primary removed, next becomes primary
- A summary line below the grid: `"● Chest — primary  · Triceps  · Front Delt"` shows current order
- On save: write one row per muscle to `exercise_muscles` with `sort_order` = position in list

The `isTimed` toggle remains unchanged.

---

## Change 3 — Expanded Exercise Library

### Seeding strategy

A new `SharedPreferences` flag `muscles_seeded_v1` (distinct from `exercises_seeded`) triggers once after schema v13:

1. Insert new exercises (those not already in the DB) by name: for each exercise in the master list, SELECT by name — if not found, INSERT
2. For every exercise in the master list below, look up its `id` by name, then upsert its muscle rows into `exercise_muscles` (delete existing rows for that exercise first, then re-insert)

This is safe to run on both fresh installs and existing installs. User-added exercises with no muscle assignments are left untouched.

### Master exercise list

Format: `name | primary | secondary...` (all timed exercises marked †)

**Chest**
| Exercise | Primary | Secondary |
|---|---|---|
| Bench Press | Chest | Triceps, Front Delt |
| Incline Bench Press | Chest | Triceps, Front Delt |
| Decline Bench Press | Chest | Triceps |
| Dumbbell Fly | Chest | Front Delt |
| Cable Fly | Chest | Front Delt |
| Pec Deck | Chest | — |
| Dips | Chest | Triceps, Front Delt |
| Push-ups | Chest | Triceps, Front Delt |

**Back**
| Exercise | Primary | Secondary |
|---|---|---|
| Deadlift | Back | Glutes, Hamstrings, Core |
| Barbell Row | Back | Biceps, Rear Delt |
| Pull-ups | Back | Biceps, Core |
| Lat Pulldown | Back | Biceps |
| Seated Cable Row | Back | Biceps, Rear Delt |
| T-Bar Row | Back | Biceps, Rear Delt |
| Single-Arm Dumbbell Row | Back | Biceps |
| Chest-Supported Row | Back | Rear Delt, Biceps |
| Straight-Arm Pulldown | Back | — |

**Shoulders**
| Exercise | Primary | Secondary |
|---|---|---|
| Overhead Press | Shoulders | Triceps, Front Delt |
| Dumbbell Shoulder Press | Shoulders | Triceps, Front Delt |
| Arnold Press | Shoulders | Triceps, Front Delt |
| Lateral Raises | Shoulders | — |
| Upright Row | Shoulders | Rear Delt, Biceps |

**Front Delt**
| Exercise | Primary | Secondary |
|---|---|---|
| Front Raise | Front Delt | Shoulders |

**Rear Delt**
| Exercise | Primary | Secondary |
|---|---|---|
| Face Pulls | Rear Delt | Shoulders |
| Reverse Fly | Rear Delt | Shoulders |

**Triceps**
| Exercise | Primary | Secondary |
|---|---|---|
| Tricep Pushdown | Triceps | — |
| Skull Crushers | Triceps | — |
| Close-Grip Bench Press | Triceps | Chest |
| Overhead Tricep Extension | Triceps | — |
| Tricep Kickback | Triceps | — |

**Biceps**
| Exercise | Primary | Secondary |
|---|---|---|
| Barbell Curl | Biceps | — |
| Dumbbell Curl | Biceps | — |
| Hammer Curl | Biceps | — |
| Preacher Curl | Biceps | — |
| Cable Curl | Biceps | — |
| Incline Dumbbell Curl | Biceps | — |

**Quads**
| Exercise | Primary | Secondary |
|---|---|---|
| Squat | Quads | Glutes, Hamstrings, Core |
| Leg Press | Quads | Glutes, Hamstrings |
| Leg Extension | Quads | — |
| Lunges | Quads | Glutes, Hamstrings |
| Hack Squat | Quads | Glutes |
| Bulgarian Split Squat | Quads | Glutes, Hamstrings |
| Goblet Squat | Quads | Glutes, Core |
| Front Squat | Quads | Glutes, Core |

**Hamstrings**
| Exercise | Primary | Secondary |
|---|---|---|
| Romanian Deadlift | Hamstrings | Glutes, Back |
| Leg Curl | Hamstrings | — |
| Nordic Curl | Hamstrings | Glutes |
| Stiff-Leg Deadlift | Hamstrings | Glutes, Back |

**Glutes**
| Exercise | Primary | Secondary |
|---|---|---|
| Hip Thrust | Glutes | Hamstrings |
| Glute Bridge | Glutes | Hamstrings |
| Sumo Squat | Glutes | Quads, Hamstrings |
| Cable Kickback | Glutes | — |

**Calves**
| Exercise | Primary | Secondary |
|---|---|---|
| Calf Raises | Calves | — |
| Seated Calf Raises | Calves | — |

**Core**
| Exercise | Primary | Secondary |
|---|---|---|
| Plank | Core | Shoulders |
| Ab Wheel Rollout | Core | Shoulders, Back |
| Cable Crunch | Core | — |
| Hanging Leg Raise | Core | — |
| Russian Twist | Core | — |
| Dead Bug | Core | — |
| Side Plank | Core | Shoulders |
| Decline Sit-up | Core | — |

**Cardio** (all timed)
| Exercise | Primary | Secondary |
|---|---|---|
| Treadmill Run | Cardio | — |
| Rowing Machine | Cardio | Back |
| Jump Rope | Cardio | — |
| Assault Bike | Cardio | — |
| Stairmaster | Cardio | — |
| Cycling | Cardio | — |

**Total: 68 exercises** (26 existing re-assigned + 42 new)

---

## Files Changed

| File | Change |
|---|---|
| `lib/database/tables/exercise_muscles_table.dart` | New table class |
| `lib/database/app_database.dart` | Add `exerciseMuscles` table, bump to v13, add migration |
| `lib/database/daos/exercises_dao.dart` | Add muscle CRUD methods + join query for primary muscle |
| `lib/utils/constants.dart` | Replace `kExerciseCategories` + `kDefaultExercises` with `kMuscleGroups` + expanded seed data |
| `lib/main.dart` | Add `muscles_seeded_v1` seeding pass after migration |
| `lib/screens/settings/exercise_library_screen.dart` | Card redesign, muscle chip grouping, edit dialog muscle picker |

---

## Out of Scope

- Filtering the list by muscle group (search by name only, unchanged)
- Using muscle groups in the WOD exercise setup screen or active session
- Removing the `category` column from the DB
