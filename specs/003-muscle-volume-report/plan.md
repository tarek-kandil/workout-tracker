# Implementation Plan: Muscle Taxonomy + Weekly Volume Report

**Branch**: `[003-muscle-volume-report]` | **Date**: 2026-09-04 | **Spec**: `specs/003-muscle-volume-report/spec.md`

**Input**: Feature specification from `/specs/003-muscle-volume-report/spec.md`

**Note**: This plan follows `.specify/templates/plan-template.md` and is implementation guidance for Flutter/Drift work.

## Summary

Replace the current broad exercise muscle tags with a 21-trainable-muscle taxonomy and compute a rolling 7-day weekly volume report. The report credits persisted completed sets by exercise-muscle role (`primary` = 1.0 set, `secondary` = 0.5 set) and down-weights explicitly easy work (`rir >= 5` = ×0.5). Circuit work needs no special persisted schema: each completed circuit exercise round is already saved as a `workout_sets` row for that exercise, so the aggregation can treat circuit and straight sets identically.

The schema moves `exercise_muscles` from implicit primacy (`sort_order == 0`) to an explicit `role TEXT` column. To satisfy the non-destructive migration requirement, v20 also adds active/review metadata: old assignment rows are never dropped; legacy rows that should no longer count are marked inactive, new taxonomy rows are inserted, and exercises with ambiguous migration are marked as needing review.

## Technical Context

**Language/Version**: Dart SDK `^3.11.3`; Flutter CI target 3.41.5

**Primary Dependencies**: Flutter, Drift `^2.26.1`, Riverpod `^2.6.1`, `build_runner`, `drift_dev`, `sqlite3` for migration tests

**Storage**: Local SQLite via Drift (`AppDatabase.schemaVersion` currently 19; feature migration is v20)

**Testing**: `flutter test`; targeted Drift migration tests with `sqlite3.openInMemory()` and provider/unit tests

**Target Platform**: Flutter mobile app (iOS/Android), local-first/offline

**Project Type**: Single Flutter app with layered `lib/database`, `lib/models`, `lib/providers`, `lib/screens`

**Performance Goals**: Weekly report returns within 3 seconds with a full year of history; aggregation should scan only `workout_sets` joined to sessions in `[now - 7 days, now)`

**Constraints**:
- Migration must be additive, guarded with `sqlite_master`/`PRAGMA table_info`, idempotent, and non-throwing on real device data.
- Preserve exercises, custom exercises, circuits, workout sessions, logged sets, and existing `exercise_muscles` rows.
- `Cardio` and `Full Body` remain non-muscle categories and must not receive landmarks or status rows.
- Missing RIR is full credit; only explicit `rir >= 5` down-weights.

**Scale/Scope**: 21 muscles, ~68 current default exercises, local single-user data, rolling 7-day read path

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The repository constitution file is still the generated placeholder and contains no concrete gates. Apply project/team gates instead:

- **Spec-first**: Passed. `specs/003-muscle-volume-report/spec.md` exists and defines FR-001 through FR-018 plus landmarks.
- **Non-destructive migrations**: Required. v20 must follow the defensive additive pattern already used in `AppDatabase` v18/v19.
- **Test coverage for schema/API changes**: Required. Add migration and computation/provider tests before release.
- **Local-first privacy**: Passed. Landmarks are static constants; no network or third-party data flow.
- **Simplicity**: Passed with one justified metadata addition. `role` is required by the feature; `isActive` + exercise review columns are justified to preserve legacy rows while excluding non-taxonomy/ambiguous data from reports.

## Project Structure

### Documentation (this feature)

```text
specs/003-muscle-volume-report/
├── spec.md              # Existing WHAT/WHY and FRs
├── plan.md              # This file
├── data-model.md        # Entities, schema, migration, computation contract
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

```text
lib/
├── database/
│   ├── app_database.dart
│   ├── daos/
│   │   ├── exercises_dao.dart
│   │   └── sets_dao.dart              # or new muscle_volume_dao.dart
│   └── tables/
│       ├── exercises_table.dart
│       └── exercise_muscles_table.dart
├── models/
│   ├── muscle_taxonomy.dart           # optional if not kept in utils/constants.dart
│   ├── volume_landmark.dart
│   └── weekly_muscle_volume.dart
├── providers/
│   └── muscle_volume_provider.dart
├── screens/
│   ├── home/                          # entry/card for report
│   ├── reports/weekly_muscle_report_screen.dart
│   └── settings/exercise_library_screen.dart
└── utils/constants.dart               # current default exercise seed data

test/
├── migration_v20_muscle_taxonomy_test.dart
├── muscle_volume_computation_test.dart
└── muscle_volume_provider_test.dart
```

**Structure Decision**: Keep the feature inside the existing Flutter app layers. Drift table changes stay in `lib/database/tables`; aggregation belongs in a DAO (`SetsDao` if keeping volume near set analytics, or `MuscleVolumeDao` if Flutter prefers feature isolation); Riverpod exposes report state to UI.

## Data and Schema Design

### Taxonomy constants

Create one canonical ordered taxonomy constant and use it everywhere muscle-volume logic needs membership/order:

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
  'Chest', 'Lats', 'Upper Back', 'Traps', 'Spinal Erectors',
  'Front Delts', 'Side Delts', 'Rear Delts',
  'Biceps', 'Triceps', 'Forearms',
  'Quads', 'Hamstrings', 'Glutes', 'Adductors', 'Abductors',
  'Hip Flexors', 'Calves',
  'Abs', 'Obliques', 'Neck',
];

const List<String> kNonMuscleTrainingCategories = ['Cardio', 'Full Body'];
```

`Cardio` and `Full Body` should remain exercise categories/style labels, not active `exercise_muscles` report rows.

### Landmark constants

Store landmarks as Dart constants, not in SQLite. They are static product defaults from the spec, versioned with code, and not user-editable in this feature.

```dart
class VolumeLandmark {
  final double mv;
  final double mev;
  final double mavLow;
  final double mavHigh;
  final double mrv;
  const VolumeLandmark({
    required this.mv,
    required this.mev,
    required this.mavLow,
    required this.mavHigh,
    required this.mrv,
  });
}

const Map<String, VolumeLandmark> kVolumeLandmarks = {
  'Chest': VolumeLandmark(mv: 4, mev: 8, mavLow: 12, mavHigh: 18, mrv: 22),
  'Lats': VolumeLandmark(mv: 4, mev: 8, mavLow: 12, mavHigh: 18, mrv: 22),
  'Upper Back': VolumeLandmark(mv: 4, mev: 8, mavLow: 12, mavHigh: 20, mrv: 24),
  'Traps': VolumeLandmark(mv: 2, mev: 6, mavLow: 10, mavHigh: 16, mrv: 20),
  'Spinal Erectors': VolumeLandmark(mv: 2, mev: 4, mavLow: 6, mavHigh: 10, mrv: 12),
  'Front Delts': VolumeLandmark(mv: 2, mev: 4, mavLow: 6, mavHigh: 10, mrv: 12),
  'Side Delts': VolumeLandmark(mv: 4, mev: 8, mavLow: 12, mavHigh: 20, mrv: 26),
  'Rear Delts': VolumeLandmark(mv: 4, mev: 8, mavLow: 12, mavHigh: 20, mrv: 24),
  'Biceps': VolumeLandmark(mv: 4, mev: 8, mavLow: 12, mavHigh: 18, mrv: 22),
  'Triceps': VolumeLandmark(mv: 4, mev: 8, mavLow: 12, mavHigh: 18, mrv: 22),
  'Forearms': VolumeLandmark(mv: 2, mev: 6, mavLow: 8, mavHigh: 14, mrv: 18),
  'Quads': VolumeLandmark(mv: 4, mev: 8, mavLow: 12, mavHigh: 18, mrv: 22),
  'Hamstrings': VolumeLandmark(mv: 4, mev: 8, mavLow: 10, mavHigh: 16, mrv: 20),
  'Glutes': VolumeLandmark(mv: 4, mev: 8, mavLow: 10, mavHigh: 18, mrv: 22),
  'Adductors': VolumeLandmark(mv: 2, mev: 4, mavLow: 6, mavHigh: 10, mrv: 14),
  'Abductors': VolumeLandmark(mv: 2, mev: 4, mavLow: 6, mavHigh: 10, mrv: 14),
  'Hip Flexors': VolumeLandmark(mv: 2, mev: 4, mavLow: 6, mavHigh: 10, mrv: 14),
  'Calves': VolumeLandmark(mv: 4, mev: 8, mavLow: 12, mavHigh: 20, mrv: 24),
  'Abs': VolumeLandmark(mv: 4, mev: 8, mavLow: 10, mavHigh: 16, mrv: 20),
  'Obliques': VolumeLandmark(mv: 2, mev: 6, mavLow: 8, mavHigh: 14, mrv: 18),
  'Neck': VolumeLandmark(mv: 0, mev: 2, mavLow: 4, mavHigh: 8, mrv: 10),
};
```

### ExerciseMuscles role design

Use a `role TEXT` column rather than storing `creditWeight REAL`.

Recommended v20 table shape:

```dart
class ExerciseMuscles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.cascade)();
  TextColumn get muscle => text()();
  IntColumn get sortOrder => integer()();
  TextColumn get role => text().withDefault(const Constant('primary'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}
```

Rationale:
- The spec and UI language are semantic (`primary`/`secondary`), not arbitrary weights.
- The report can centralize role weights in code: `primary = 1.0`, `secondary = 0.5`.
- It avoids user-created floating-point values and keeps future role changes/messaging easier.

Add exercise-level review metadata:

```dart
class Exercises extends Table {
  // existing columns...
  BoolColumn get muscleNeedsReview =>
      boolean().withDefault(const Constant(false))();
  TextColumn get muscleReviewNote => text().nullable()();
}
```

This is the surfaced representation for FR-016/FR-017. Exercise library rows and report warnings can badge exercises where `muscle_needs_review = 1`; the review note explains which legacy tags were mapped or excluded.

## Migration Strategy (schema v20)

### Goals

- Preserve every existing exercise, circuit template, workout session, and logged set.
- Preserve existing `exercise_muscles` rows by never deleting them in the migration.
- Add explicit roles using current primacy convention: `sort_order == 0` -> `primary`, all other rows -> `secondary`.
- Map legacy broad tags into active 21-muscle rows where possible.
- Mark ambiguous/unmapped exercises for review rather than inventing extra volume.

### Defensive migration shape

In `AppDatabase.onUpgrade`, add a guarded `if (from < 20)` block:

1. Read `sqlite_master` once and check whether `exercises` and `exercise_muscles` exist.
2. For `exercise_muscles`, read `PRAGMA table_info(exercise_muscles)` and add columns only when absent:
   - `role TEXT NOT NULL DEFAULT 'primary'`
   - `is_active INTEGER NOT NULL DEFAULT 1`
3. For `exercises`, read `PRAGMA table_info(exercises)` and add columns only when absent:
   - `muscle_needs_review INTEGER NOT NULL DEFAULT 0`
   - `muscle_review_note TEXT NULL`
4. Normalize existing roles:
   - `UPDATE exercise_muscles SET role = CASE WHEN sort_order = 0 THEN 'primary' ELSE 'secondary' END WHERE role NOT IN ('primary', 'secondary') OR role IS NULL;`
5. Apply legacy mapping using `INSERT ... SELECT ... WHERE NOT EXISTS` and then mark legacy broad rows inactive where they are not exact taxonomy names.
6. Use only guarded SQL; if a table/column is missing, skip that sub-step.

### Legacy broad-tag mapping

| Legacy tag | Active taxonomy row inserted | Role | Needs review? | Note |
|------------|------------------------------|------|---------------|------|
| Chest | Chest | Preserve existing row; `sort_order 0` primary else secondary | No | Exact 1:1 |
| Biceps | Biceps | Preserve | No | Exact 1:1 |
| Triceps | Triceps | Preserve | No | Exact 1:1 |
| Quads | Quads | Preserve | No | Exact 1:1 |
| Hamstrings | Hamstrings | Preserve | No | Exact 1:1 |
| Glutes | Glutes | Preserve | No | Exact 1:1 |
| Calves | Calves | Preserve | No | Exact 1:1 |
| Front Delt | Front Delts | Preserve primacy from legacy row | No | Legacy singular renamed; old row inactive, plural row active |
| Rear Delt | Rear Delts | Preserve primacy from legacy row | No | Legacy singular renamed; old row inactive, plural row active |
| Back | Lats | Preserve primacy from legacy row | Yes | `Back` may mean Lats, Upper Back, Traps, or Spinal Erectors; choose Lats as single likely default and ask user to review |
| Shoulders | Side Delts | Preserve primacy from legacy row | Yes | Generic shoulder tag may mean Front/Side/Rear Delts; choose Side Delts as single likely default and ask user to review |
| Core | Abs | Preserve primacy from legacy row | Yes | Generic core tag may mean Abs or Obliques; choose Abs as single likely default and ask user to review |
| Full Body | none | n/a | Yes if exercise has no other active taxonomy muscle | Non-muscle category; do not fabricate multi-muscle volume |
| Cardio | none | n/a | No for default cardio exercises; yes if a non-cardio/custom exercise is left with no active taxonomy muscle | Non-muscle category; excluded from hypertrophy landmarks |

### Default exercise re-seeding

After the v20 schema is available, update `main.dart` startup seeding from `muscles_seeded_v1` to an idempotent `muscles_seeded_v2` pass:

1. Insert any missing default exercises by name, as v1 already does.
2. For each default strength/hypertrophy exercise in the new role-aware `kExerciseMuscleAssignments`, sync assignments by exercise name:
   - Mark that exercise's current active `exercise_muscles` rows inactive (`is_active = 0`), not deleted.
   - Insert the exact v2 taxonomy assignment rows with explicit role and active=true.
   - Clear `muscle_needs_review` for default exercises that have exact v2 assignments.
3. For default pure cardio/timed conditioning exercises (`Treadmill Run`, `Jump Rope`, `Assault Bike`, `Stairmaster`, `Cycling`, and `Rowing Machine` unless Product/Coach later decide it should count), leave no active muscle-volume rows and clear review because exclusion is intentional.
4. Do not set `muscles_seeded_v2` if any part throws; retry next launch, matching the existing non-fatal startup seeding pattern.

This keeps the structural migration tiny and safe while allowing the seed pass to use Dart constants/DAO helpers.

## Effective-Set Computation

### Completed set definition

`WorkoutSets` has no completed flag. A set is completed once it is persisted by `ActiveSessionScreen._finish()`, which skips:
- skipped session items and skipped standalone set indices,
- non-timed rows with `reps == 0`,
- timed rows with `durationSeconds == 0`.

The report should still defensively filter out accidental zero rows:

```sql
AND (
  (e.is_timed = 1 AND COALESCE(ws.duration_seconds, 0) > 0)
  OR
  (e.is_timed = 0 AND ws.reps > 0)
)
```

### DAO query shape

Add `getRollingMuscleEffectiveSets(DateTime from, DateTime to)` to `SetsDao` or a new `MuscleVolumeDao`.

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
  AND em.muscle IN (
    'Chest', 'Lats', 'Upper Back', 'Traps', 'Spinal Erectors',
    'Front Delts', 'Side Delts', 'Rear Delts',
    'Biceps', 'Triceps', 'Forearms',
    'Quads', 'Hamstrings', 'Glutes', 'Adductors', 'Abductors',
    'Hip Flexors', 'Calves', 'Abs', 'Obliques', 'Neck'
  )
  AND (
    (e.is_timed = 1 AND COALESCE(ws.duration_seconds, 0) > 0)
    OR (e.is_timed = 0 AND ws.reps > 0)
  )
GROUP BY em.muscle;
```

Build the final result in Dart by iterating over `kTrainableMuscles` so all 21 muscles appear, defaulting missing rows to `0.0`.

### Return shape

```dart
enum MuscleVolumeStatus { undertrained, optimal, overtrained }

class WeeklyMuscleVolume {
  final String muscle;
  final String region;
  final double effectiveSets;
  final int contributingSets;
  final VolumeLandmark landmark;
  final MuscleVolumeStatus status;
  final bool belowMaintenance; // effectiveSets < landmark.mv
  const WeeklyMuscleVolume(...);
}
```

Status logic:

```dart
if (effectiveSets < landmark.mev) undertrained;
else if (effectiveSets <= landmark.mrv) optimal;
else overtrained;
```

`belowMaintenance` adds context only; status remains `undertrained`.

### Provider

Create:

```dart
final weeklyMuscleVolumeProvider =
    FutureProvider<List<WeeklyMuscleVolume>>((ref) async {
  final db = ref.watch(databaseProvider);
  final to = DateTime.now();
  final from = to.subtract(const Duration(days: 7));
  final rows = await db.setsDao.getRollingMuscleEffectiveSets(from, to);
  return buildWeeklyMuscleVolumeReport(rows, kVolumeLandmarks);
});
```

If the report should be manually refreshable, use an injectable clock/helper for tests instead of calling `DateTime.now()` deep inside the DAO.

## Circuits

No new circuit tables are required. Circuits are template-time groups (`wod_exercise_groups` + `wod_template_exercises.group_id`). At finish time, each completed circuit exercise round is persisted into `workout_sets` with the same `exercise_id` used by straight sets. Therefore the volume query should not join circuit templates; it should aggregate persisted set rows by exercise assignment.

Example: a 3-round circuit containing Pull-ups and Push-ups produces up to three persisted Pull-up set rows and three Push-up set rows. Each row joins to its exercise's active muscle assignments and receives the same primary/secondary/RIR credit as a straight set.

## Implementation Build Order

1. **Constants/models**
   - Add taxonomy, non-muscle categories, landmarks, role weights, and role-aware default exercise assignments.
   - Add `VolumeLandmark` and `WeeklyMuscleVolume` models.
2. **Drift schema**
   - Add `role` and `isActive` to `ExerciseMuscles`.
   - Add `muscleNeedsReview` and `muscleReviewNote` to `Exercises`.
   - Bump `AppDatabase.schemaVersion` to 20.
   - Run `flutter pub run build_runner build --delete-conflicting-outputs`.
3. **Migration v20**
   - Add guarded column creation and broad-tag remapping.
   - Add tests before shipping.
4. **DAO updates**
   - Replace `setMusclesForExercise(int, List<String>)` call sites with role-aware assignment APIs.
   - Ensure `getMusclesForExercise`/watchers filter `is_active = 1`.
   - Add `getExercisesNeedingMuscleReview`.
   - Add the effective-set aggregation query.
5. **Startup seeding**
   - Add `muscles_seeded_v2` pass in `main.dart`.
   - Sync default exercise assignments by name without deleting legacy rows.
6. **UI/provider**
   - Add weekly report provider/screen.
   - Update exercise library editor to require at least one primary muscle for volume-contributing exercises and to show review badges/notes.
7. **Tests**
   - v19 -> v20 non-destructive migration test.
   - Effective-set computation tests.
   - Provider/report result test.
8. **Validation**
   - Run targeted tests first.
   - Run full `flutter test` before PR.

## Test Plan

### Migration tests

Add `test/migration_v20_muscle_taxonomy_test.dart`:

- Seed a v19 DB with:
  - `exercises` rows for default and custom exercises,
  - `exercise_muscles` rows with exact tags, singular delts, ambiguous Back/Shoulders/Core, Full Body/Cardio,
  - `workout_sessions`, `workout_sets`, `wod_exercise_groups`, and `wod_template_exercises` rows representing straight and circuit history.
- Open with schema v20 and assert:
  - v20 columns exist.
  - all original exercise/session/set/circuit row counts are unchanged.
  - original `exercise_muscles` rows still exist (inactive when superseded).
  - `sort_order == 0` became `primary`; other rows became `secondary`.
  - safe tags remain active and exact.
  - ambiguous tags insert one active likely mapping and set `muscle_needs_review = 1`.
  - `Full Body`/`Cardio` do not become active landmark muscles.
- Add an idempotence test opening a fresh v20 DB and re-opening migrated data without throwing.

### Computation tests

Add `test/muscle_volume_computation_test.dart`:

- Primary full-credit: 3 Bench Press rows -> Chest = 3.0.
- Secondary full-credit: 3 Bench Press rows -> Triceps = 1.5.
- RIR down-weight: primary set with `rir = 5` -> 0.5; secondary with `rir = 5` -> 0.25.
- Missing RIR: `rir NULL` -> full role credit.
- Boundary dates: include `s.date >= from`, exclude `s.date >= to`.
- Non-active/legacy tags: inactive Back/Cardio rows do not count.
- Circuit case: create persisted set rows as active session finish does for each circuit exercise/round; totals match straight-set rules.

### Provider/report tests

Add `test/muscle_volume_provider_test.dart`:

- Provider returns exactly 21 rows in taxonomy order for an empty DB.
- Status boundaries: below MEV -> `undertrained`; MEV through MRV -> `optimal`; above MRV -> `overtrained`; below MV sets `belowMaintenance`.
- Report includes review/unmapped exercises separately if the UI card needs a warning banner.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Additional `is_active` and exercise review metadata in v20 | Required to preserve legacy `exercise_muscles` rows while preventing old broad tags from inflating reports and surfacing FR-016/FR-017 review state | Updating/deleting rows in place is simpler but either loses legacy rows or silently maps ambiguous tags without review |
