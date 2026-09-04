# Data Model: Muscle Taxonomy + Weekly Volume Report

**Feature**: `003-muscle-volume-report`  
**Date**: 2026-09-04  
**Source spec**: `specs/003-muscle-volume-report/spec.md`

## Entities

### Muscle

A trainable muscle in the 21-muscle taxonomy.

| Field | Type | Notes |
|-------|------|-------|
| name | `String` | One of `kTrainableMuscles`; stable display key |
| region | `String` | Chest, Back, Shoulders, Arms, Legs, Core, Neck |
| landmark | `VolumeLandmark` | Static weekly effective-set landmarks |

Muscles are not stored in SQLite in this feature. They are product constants so every report can always render all 21 rows.

### ExerciseMuscleAssignment

The active relationship between an exercise and a trainable muscle.

| Field | Type | Stored in | Notes |
|-------|------|-----------|-------|
| id | `int` | `exercise_muscles.id` | Existing PK |
| exerciseId | `int` | `exercise_muscles.exercise_id` | Existing FK to `exercises.id` |
| muscle | `String` | `exercise_muscles.muscle` | Must be one of `kTrainableMuscles` for active report rows |
| sortOrder | `int` | `exercise_muscles.sort_order` | Existing display order; primary rows should sort first |
| role | `String` | `exercise_muscles.role` | New v20 value: `primary` or `secondary` |
| isActive | `bool` | `exercise_muscles.is_active` | New v20 value; inactive rows preserve legacy assignments but do not count |

Rules:
- An exercise that contributes to muscle volume must have at least one active `primary` assignment.
- Active `secondary` assignments are optional.
- Report queries must require `is_active = 1` and `muscle IN kTrainableMuscles`.
- Role weights are code constants, not stored per row:
  - `primary` -> `1.0`
  - `secondary` -> `0.5`

### Exercise muscle review state

Review state is stored on the existing `exercises` row.

| Field | Type | Stored in | Notes |
|-------|------|-----------|-------|
| muscleNeedsReview | `bool` | `exercises.muscle_needs_review` | `true` when migration had to guess or could not map legacy tags |
| muscleReviewNote | `String?` | `exercises.muscle_review_note` | Human-readable migration note for the exercise editor/report warning |

UI contract:
- Exercise library shows a "Needs muscle review" badge when `muscleNeedsReview` is true.
- Exercise edit sheet shows `muscleReviewNote` and clears the flag after the athlete saves at least one active primary muscle, or intentionally marks the exercise excluded from muscle volume if that UI state is added.
- Weekly report may show a warning section listing review/unmapped exercises in the 7-day window; their unassigned portions do not count.

### VolumeLandmark

Static reference values in effective sets per rolling 7 days.

| Field | Type | Notes |
|-------|------|-------|
| mv | `double` | Maintenance volume |
| mev | `double` | Minimum effective volume |
| mavLow | `double` | Lower target adaptive range |
| mavHigh | `double` | Upper target adaptive range |
| mrv | `double` | Max recoverable volume |

Landmarks are not stored in DB. They are static product constants from the spec, not editable user data. Keeping them in code avoids a migration for every future tuning pass and guarantees availability on empty databases.

### WeeklyMuscleVolume

Computed report row for one muscle.

| Field | Type | Notes |
|-------|------|-------|
| muscle | `String` | One of the 21 taxonomy muscles |
| region | `String` | Derived from `kMusclesByRegion` |
| effectiveSets | `double` | Rolling 7-day sum |
| contributingSets | `int` | Count of persisted set-assignment pairs that contributed |
| landmark | `VolumeLandmark` | From `kVolumeLandmarks[muscle]` |
| status | `MuscleVolumeStatus` | `undertrained`, `optimal`, `overtrained` |
| belowMaintenance | `bool` | `effectiveSets < landmark.mv`; note only |

Status boundaries:
- `effectiveSets < MEV` -> `undertrained`
- `MEV <= effectiveSets <= MRV` -> `optimal`
- `effectiveSets > MRV` -> `overtrained`
- If `effectiveSets < MV`, keep `undertrained` and add below-maintenance context.

## Constants

### Taxonomy by region

```dart
const Map<String, List<String>> kMusclesByRegion = {
  'Chest': ['Chest'],
  'Back': ['Lats', 'Upper Back', 'Traps', 'Spinal Erectors'],
  'Shoulders': ['Front Delts', 'Side Delts', 'Rear Delts'],
  'Arms': ['Biceps', 'Triceps', 'Forearms'],
  'Legs': [
    'Quads', 'Hamstrings', 'Glutes', 'Adductors', 'Abductors',
    'Hip Flexors', 'Calves',
  ],
  'Core': ['Abs', 'Obliques'],
  'Neck': ['Neck'],
};

const List<String> kTrainableMuscles = [
  'Chest',
  'Lats',
  'Upper Back',
  'Traps',
  'Spinal Erectors',
  'Front Delts',
  'Side Delts',
  'Rear Delts',
  'Biceps',
  'Triceps',
  'Forearms',
  'Quads',
  'Hamstrings',
  'Glutes',
  'Adductors',
  'Abductors',
  'Hip Flexors',
  'Calves',
  'Abs',
  'Obliques',
  'Neck',
];

const List<String> kNonMuscleTrainingCategories = ['Cardio', 'Full Body'];
```

### Landmarks

| Muscle | MV | MEV | MAV low | MAV high | MRV |
|--------|----|-----|---------|----------|-----|
| Chest | 4 | 8 | 12 | 18 | 22 |
| Lats | 4 | 8 | 12 | 18 | 22 |
| Upper Back | 4 | 8 | 12 | 20 | 24 |
| Traps | 2 | 6 | 10 | 16 | 20 |
| Spinal Erectors | 2 | 4 | 6 | 10 | 12 |
| Front Delts | 2 | 4 | 6 | 10 | 12 |
| Side Delts | 4 | 8 | 12 | 20 | 26 |
| Rear Delts | 4 | 8 | 12 | 20 | 24 |
| Biceps | 4 | 8 | 12 | 18 | 22 |
| Triceps | 4 | 8 | 12 | 18 | 22 |
| Forearms | 2 | 6 | 8 | 14 | 18 |
| Quads | 4 | 8 | 12 | 18 | 22 |
| Hamstrings | 4 | 8 | 10 | 16 | 20 |
| Glutes | 4 | 8 | 10 | 18 | 22 |
| Adductors | 2 | 4 | 6 | 10 | 14 |
| Abductors | 2 | 4 | 6 | 10 | 14 |
| Hip Flexors | 2 | 4 | 6 | 10 | 14 |
| Calves | 4 | 8 | 12 | 20 | 24 |
| Abs | 4 | 8 | 10 | 16 | 20 |
| Obliques | 2 | 6 | 8 | 14 | 18 |
| Neck | 0 | 2 | 4 | 8 | 10 |

### Role-aware default exercise assignments

Use a role-aware value object instead of relying on list position:

```dart
enum ExerciseMuscleRole { primary, secondary }

class ExerciseMuscleSeed {
  final String muscle;
  final ExerciseMuscleRole role;
  const ExerciseMuscleSeed.primary(this.muscle) : role = ExerciseMuscleRole.primary;
  const ExerciseMuscleSeed.secondary(this.muscle) : role = ExerciseMuscleRole.secondary;
}
```

Proposed v2 seed map for strength/hypertrophy defaults:

| Exercise | Primary | Secondary |
|----------|---------|-----------|
| Bench Press | Chest | Triceps, Front Delts |
| Incline Bench Press | Chest | Front Delts, Triceps |
| Decline Bench Press | Chest | Triceps |
| Dumbbell Fly | Chest | Front Delts |
| Cable Fly | Chest | — |
| Pec Deck | Chest | — |
| Dips | Chest | Triceps, Front Delts |
| Push-ups | Chest | Triceps, Front Delts |
| Deadlift | Spinal Erectors | Glutes, Hamstrings, Traps, Upper Back |
| Barbell Row | Upper Back | Lats, Biceps, Rear Delts |
| Pull-ups | Lats | Biceps, Upper Back |
| Lat Pulldown | Lats | Biceps, Upper Back |
| Seated Cable Row | Upper Back | Lats, Biceps, Rear Delts |
| T-Bar Row | Upper Back | Lats, Biceps, Rear Delts |
| Single-Arm Dumbbell Row | Lats | Upper Back, Biceps |
| Chest-Supported Row | Upper Back | Lats, Rear Delts, Biceps |
| Straight-Arm Pulldown | Lats | — |
| Overhead Press | Front Delts | Side Delts, Triceps |
| Dumbbell Shoulder Press | Front Delts | Side Delts, Triceps |
| Arnold Press | Front Delts | Side Delts, Triceps |
| Lateral Raises | Side Delts | — |
| Upright Row | Side Delts | Traps, Rear Delts, Biceps |
| Front Raise | Front Delts | Side Delts |
| Face Pulls | Rear Delts | Traps, Upper Back |
| Reverse Fly | Rear Delts | Upper Back |
| Tricep Pushdown | Triceps | — |
| Skull Crushers | Triceps | — |
| Close-Grip Bench Press | Triceps | Chest, Front Delts |
| Overhead Tricep Extension | Triceps | — |
| Tricep Kickback | Triceps | — |
| Barbell Curl | Biceps | — |
| Dumbbell Curl | Biceps | — |
| Hammer Curl | Biceps | Forearms |
| Preacher Curl | Biceps | — |
| Cable Curl | Biceps | — |
| Incline Dumbbell Curl | Biceps | — |
| Squat | Quads | Glutes, Hamstrings, Abs, Spinal Erectors |
| Leg Press | Quads | Glutes, Hamstrings |
| Leg Extension | Quads | — |
| Lunges | Quads | Glutes, Hamstrings, Adductors |
| Hack Squat | Quads | Glutes |
| Bulgarian Split Squat | Quads | Glutes, Hamstrings, Adductors |
| Goblet Squat | Quads | Glutes, Abs, Spinal Erectors |
| Front Squat | Quads | Glutes, Abs, Spinal Erectors |
| Romanian Deadlift | Hamstrings | Glutes, Spinal Erectors |
| Leg Curl | Hamstrings | — |
| Nordic Curl | Hamstrings | Glutes |
| Stiff-Leg Deadlift | Hamstrings | Glutes, Spinal Erectors |
| Hip Thrust | Glutes | Hamstrings |
| Glute Bridge | Glutes | Hamstrings |
| Sumo Squat | Glutes | Quads, Hamstrings, Adductors |
| Cable Kickback | Glutes | — |
| Calf Raises | Calves | — |
| Seated Calf Raises | Calves | — |
| Plank | Abs | Obliques |
| Ab Wheel Rollout | Abs | Lats, Front Delts |
| Cable Crunch | Abs | — |
| Hanging Leg Raise | Abs | Hip Flexors |
| Russian Twist | Obliques | Abs |
| Dead Bug | Abs | Hip Flexors |
| Side Plank | Obliques | Abs |
| Decline Sit-up | Abs | Hip Flexors |

Default pure cardio/timed conditioning exercises remain in the exercise library/category system but should have no active muscle-volume assignments by default:

- Treadmill Run
- Rowing Machine
- Jump Rope
- Assault Bike
- Stairmaster
- Cycling

## Drift schema changes (v20)

### `exercise_muscles`

Current columns:

- `id`
- `exercise_id`
- `muscle`
- `sort_order`

Add:

| Column | Drift | SQLite | Default | Purpose |
|--------|-------|--------|---------|---------|
| `role` | `TextColumn` | `TEXT NOT NULL` | `'primary'` | Explicit primary/secondary assignment |
| `is_active` | `BoolColumn` | `INTEGER NOT NULL` | `1` | Preserve legacy rows without counting them |

Recommended role constants:

```dart
const String kMuscleRolePrimary = 'primary';
const String kMuscleRoleSecondary = 'secondary';

const Map<String, double> kMuscleRoleWeights = {
  kMuscleRolePrimary: 1.0,
  kMuscleRoleSecondary: 0.5,
};
```

### `exercises`

Add:

| Column | Drift | SQLite | Default | Purpose |
|--------|-------|--------|---------|---------|
| `muscle_needs_review` | `BoolColumn` | `INTEGER NOT NULL` | `0` | Surface ambiguous/unmapped migrated assignments |
| `muscle_review_note` | `TextColumn nullable` | `TEXT NULL` | `NULL` | Explain what migration did |

## Migration v19 -> v20

### Non-destructive invariants

- Do not drop tables.
- Do not delete from `exercise_muscles`.
- Do not modify `workout_sets`, `workout_sessions`, `wod_exercise_groups`, or `wod_template_exercises` except by reading them in tests.
- Preserve exercise IDs and set/session IDs.
- Make every SQL step conditional on table/column existence.
- Use `INSERT ... SELECT ... WHERE NOT EXISTS` for mapped active rows to keep the migration idempotent.

### Role assignment

For all legacy rows:

| Legacy condition | New role |
|------------------|----------|
| `sort_order = 0` | `primary` |
| `sort_order > 0` | `secondary` |
| `sort_order IS NULL` (defensive only) | `secondary`, unless it is the only row for the exercise; implementation may leave default primary if detecting this is too costly |

### Legacy broad-tag mapping table

| Old tag | New active taxonomy muscle | Active? | Needs review? | Migration behavior |
|---------|----------------------------|---------|---------------|--------------------|
| Chest | Chest | yes | no | Keep existing row active; set role from `sort_order` |
| Biceps | Biceps | yes | no | Keep active |
| Triceps | Triceps | yes | no | Keep active |
| Quads | Quads | yes | no | Keep active |
| Hamstrings | Hamstrings | yes | no | Keep active |
| Glutes | Glutes | yes | no | Keep active |
| Calves | Calves | yes | no | Keep active |
| Front Delt | Front Delts | yes via new row | no | Insert plural active row; mark singular legacy row inactive |
| Rear Delt | Rear Delts | yes via new row | no | Insert plural active row; mark singular legacy row inactive |
| Back | Lats | yes via new row | yes | Insert Lats with preserved role; mark Back inactive; note possible Lats/Upper Back/Traps/Spinal Erectors |
| Shoulders | Side Delts | yes via new row | yes | Insert Side Delts with preserved role; mark Shoulders inactive; note possible Front/Side/Rear Delts |
| Core | Abs | yes via new row | yes | Insert Abs with preserved role; mark Core inactive; note possible Abs/Obliques |
| Full Body | none | no | yes if no other active taxonomy row remains | Mark inactive; note cannot safely split across many muscles |
| Cardio | none | no | no for default cardio; yes if no active taxonomy row remains on a custom/non-cardio exercise | Mark inactive; do not count toward landmarks |

### Suggested guarded SQL fragments

Structural column guards should mirror v18/v19:

```dart
final tables = await customSelect(
  "SELECT name FROM sqlite_master WHERE type='table'",
).get();
final tableNames = tables.map((r) => r.read<String>('name')).toSet();

if (tableNames.contains('exercise_muscles')) {
  final cols = await customSelect('PRAGMA table_info(exercise_muscles)').get();
  final colNames = cols.map((r) => r.read<String>('name')).toSet();
  if (!colNames.contains('role')) {
    await m.addColumn(exerciseMuscles, exerciseMuscles.role);
  }
  if (!colNames.contains('is_active')) {
    await m.addColumn(exerciseMuscles, exerciseMuscles.isActive);
  }
}
```

Mapping pattern:

```sql
INSERT INTO exercise_muscles (exercise_id, muscle, sort_order, role, is_active)
SELECT legacy.exercise_id,
       'Lats',
       legacy.sort_order,
       CASE WHEN legacy.sort_order = 0 THEN 'primary' ELSE 'secondary' END,
       1
FROM exercise_muscles legacy
WHERE legacy.muscle = 'Back'
  AND NOT EXISTS (
    SELECT 1
    FROM exercise_muscles existing
    WHERE existing.exercise_id = legacy.exercise_id
      AND existing.muscle = 'Lats'
      AND existing.is_active = 1
  );

UPDATE exercise_muscles
SET is_active = 0
WHERE muscle = 'Back';
```

Review flag pattern:

```sql
UPDATE exercises
SET muscle_needs_review = 1,
    muscle_review_note = COALESCE(muscle_review_note || ' ', '') ||
      'Migrated legacy Back to Lats; review for Upper Back, Traps, or Spinal Erectors.'
WHERE id IN (
  SELECT DISTINCT exercise_id FROM exercise_muscles WHERE muscle = 'Back'
);
```

Use string literals only for the known legacy tags above; avoid dynamic SQL.

### Startup seed v2

The migration should not import the large default map. Instead, add a non-fatal startup seed block like the current `muscles_seeded_v1` block:

```dart
final musclesSeededV2 = prefs.getBool('muscles_seeded_v2') ?? false;
if (!musclesSeededV2) {
  final dao = db.exercisesDao;
  final existingByName = await dao.getExerciseIdsByName();

  // Insert missing default exercises by name.
  // Then sync role-aware default assignments by name.
  for (final entry in kExerciseMuscleAssignments.entries) {
    final id = existingByName[entry.key];
    if (id != null) {
      await dao.replaceActiveMusclesForExercise(id, entry.value);
      await dao.clearMuscleReview(id);
    }
  }

  await prefs.setBool('muscles_seeded_v2', true);
}
```

`replaceActiveMusclesForExercise` must not delete legacy rows:

1. `UPDATE exercise_muscles SET is_active = 0 WHERE exercise_id = ? AND is_active = 1`
2. Insert active rows from the role-aware seed list.
3. Sort primary muscles before secondary muscles. If multiple primary muscles are ever allowed, keep caller order.

## DAO contracts

### ExercisesDao

Add/replace:

```dart
Future<List<ExerciseMuscle>> getMusclesForExercise(int exerciseId);

Future<void> setMusclesForExerciseRoles(
  int exerciseId,
  List<ExerciseMuscleSeed> assignments, {
  bool clearReview = true,
});

Future<void> replaceActiveMusclesForExercise(
  int exerciseId,
  List<ExerciseMuscleSeed> assignments,
);

Stream<Map<int, List<ExerciseMuscle>>> watchAllMuscleAssignmentMap();

Future<List<Exercise>> getExercisesNeedingMuscleReview();
```

Behavior:
- Reads/watchers filter `is_active = 1`.
- `setMusclesForExerciseRoles` validates at least one primary if `assignments.isNotEmpty`.
- Saving an empty assignment is allowed only for intentionally non-volume exercises; otherwise UI should block it.
- Existing `setMusclesForExercise(int, List<String>)` should be removed or kept as a compatibility wrapper that maps index 0 to primary and others to secondary.

### Volume aggregation DAO

Either add to `SetsDao` near weekly analytics or create `MuscleVolumeDao`:

```dart
class MuscleEffectiveSetRow {
  final String muscle;
  final double effectiveSets;
  final int contributingSets;
  const MuscleEffectiveSetRow(...);
}

Future<List<MuscleEffectiveSetRow>> getRollingMuscleEffectiveSets(
  DateTime from,
  DateTime to,
);
```

SQL shape:

```sql
SELECT
  em.muscle AS muscle,
  COALESCE(SUM(
    CASE em.role
      WHEN 'primary' THEN 1.0
      WHEN 'secondary' THEN 0.5
      ELSE CASE WHEN em.sort_order = 0 THEN 1.0 ELSE 0.5 END
    END
    *
    CASE
      WHEN ws.rir IS NOT NULL AND ws.rir >= 5.0 THEN 0.5
      ELSE 1.0
    END
  ), 0.0) AS effective_sets,
  COUNT(*) AS contributing_sets
FROM workout_sets ws
JOIN workout_sessions s ON s.id = ws.session_id
JOIN exercises e ON e.id = ws.exercise_id
JOIN exercise_muscles em ON em.exercise_id = ws.exercise_id
WHERE s.date >= ? AND s.date < ?
  AND em.is_active = 1
  AND em.muscle IN (/* kTrainableMuscles */)
  AND (
    (e.is_timed = 1 AND COALESCE(ws.duration_seconds, 0) > 0)
    OR (e.is_timed = 0 AND ws.reps > 0)
  )
GROUP BY em.muscle;
```

Bind dates as current code does:

```dart
Variable.withInt(from.millisecondsSinceEpoch ~/ 1000)
Variable.withInt(to.millisecondsSinceEpoch ~/ 1000)
```

## Computation details

For each completed set in `[now - 7 days, now)`:

```text
roleWeight = primary ? 1.0 : 0.5
rirMultiplier = (rir != null && rir >= 5.0) ? 0.5 : 1.0
credit = roleWeight * rirMultiplier
```

Then sum by active taxonomy muscle.

Examples:

| Case | Credit |
|------|--------|
| Primary, RIR null | 1.0 |
| Primary, RIR 0-4.5 | 1.0 |
| Primary, RIR 5+ | 0.5 |
| Secondary, RIR null | 0.5 |
| Secondary, RIR 0-4.5 | 0.5 |
| Secondary, RIR 5+ | 0.25 |

No cap is applied across muscles. One compound set can credit multiple muscles.

## Circuits

Circuit templates are modeled by:

- `wod_exercise_groups`: circuit group metadata (`rounds`, rest timing, name)
- `wod_template_exercises.group_id`: exercise membership/order inside a circuit

Completed history is modeled by `workout_sets`, not by circuit tables. At finish, the active session loops through every unskipped circuit exercise and persists each non-zero round as a `workout_sets` row for that exercise. Therefore:

- The weekly report should count each persisted circuit exercise row.
- No join to `wod_exercise_groups` is needed for volume.
- Circuit and straight sets use the same query, role weights, and RIR multiplier.

## Report provider and return shape

Provider:

```dart
final weeklyMuscleVolumeProvider =
    FutureProvider<List<WeeklyMuscleVolume>>((ref) async {
  final db = ref.watch(databaseProvider);
  final to = DateTime.now();
  final from = to.subtract(const Duration(days: 7));
  final rows = await db.setsDao.getRollingMuscleEffectiveSets(from, to);
  return buildWeeklyMuscleVolumeReport(rows);
});
```

Pure Dart builder:

```dart
List<WeeklyMuscleVolume> buildWeeklyMuscleVolumeReport(
  List<MuscleEffectiveSetRow> rows,
) {
  final byMuscle = {for (final row in rows) row.muscle: row};
  return [
    for (final muscle in kTrainableMuscles)
      WeeklyMuscleVolume.from(
        muscle: muscle,
        region: regionForMuscle(muscle),
        effectiveSets: byMuscle[muscle]?.effectiveSets ?? 0.0,
        contributingSets: byMuscle[muscle]?.contributingSets ?? 0,
        landmark: kVolumeLandmarks[muscle]!,
      ),
  ];
}
```

## Implementation files

Expected new files:

- `lib/models/volume_landmark.dart`
- `lib/models/weekly_muscle_volume.dart`
- `lib/providers/muscle_volume_provider.dart`
- Optional: `lib/database/daos/muscle_volume_dao.dart` if not adding aggregation to `SetsDao`
- Optional: `lib/models/exercise_muscle_seed.dart` if seed objects are not colocated with constants
- `test/migration_v20_muscle_taxonomy_test.dart`
- `test/muscle_volume_computation_test.dart`
- `test/muscle_volume_provider_test.dart`

Expected touched files:

- `lib/utils/constants.dart`
- `lib/database/tables/exercise_muscles_table.dart`
- `lib/database/tables/exercises_table.dart`
- `lib/database/app_database.dart`
- `lib/database/daos/exercises_dao.dart`
- `lib/database/daos/sets_dao.dart` or `lib/database/daos/muscle_volume_dao.dart`
- `lib/main.dart`
- `lib/screens/settings/exercise_library_screen.dart`
- Report entry screen/card under `lib/screens/home/` or `lib/screens/reports/`
- Generated Drift files after `build_runner`

Codegen command after schema/DAO changes:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## Validation plan

Targeted first:

```bash
flutter test test/migration_v20_muscle_taxonomy_test.dart test/muscle_volume_computation_test.dart test/muscle_volume_provider_test.dart
```

Then full suite:

```bash
flutter test
```

Required assertions:

- v19 -> v20 migration preserves all exercises, sessions, sets, circuits, and original `exercise_muscles` rows.
- v20 migration is idempotent and guarded when tables/columns already exist.
- Default v2 seeding syncs by exercise name and never deletes legacy muscle rows.
- Effective-set math matches primary/secondary/RIR rules.
- Circuit persisted rows count exactly like straight sets.
- Report returns all 21 muscles, including zero-volume muscles.
