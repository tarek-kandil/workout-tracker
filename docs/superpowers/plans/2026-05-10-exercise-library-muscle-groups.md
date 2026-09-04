# Exercise Library — Muscle Groups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single `category` field on exercises with a structured multi-muscle system (first = primary), redesign exercise cards to be larger with muscle chips, expand the library from 26 to 68 exercises with expert muscle assignments.

**Architecture:** New `exercise_muscles` table holds (exerciseId, muscle, sortOrder) rows. A single reactive query loads all muscle rows upfront into a `Map<int, List<String>>` (exerciseId → ordered muscles); the screen groups exercises by `muscles.first` in Dart. A one-time seeding pass (flag `muscles_seeded_v1`) inserts new exercises and muscle assignments without touching user data.

**Tech Stack:** Flutter, Riverpod (StreamProvider), Drift ORM + build_runner, SharedPreferences for seeding flag.

---

## File Map

| File | Change |
|---|---|
| `lib/database/tables/exercise_muscles_table.dart` | New — `ExerciseMuscles` Drift table |
| `lib/database/app_database.dart` | Add table to `@DriftDatabase`, bump v12 → v13, add migration |
| `lib/database/daos/exercises_dao.dart` | Add `getMusclesForExercise`, `setMusclesForExercise`, `watchAllMuscleMap` |
| `lib/utils/constants.dart` | Replace `kExerciseCategories`/`kDefaultExercises` with `kMuscleGroups`, expanded `kDefaultExercises`, `kExerciseMuscles` |
| `lib/providers/exercise_providers.dart` | Add `exerciseMuscleMapProvider` |
| `lib/main.dart` | Add `muscles_seeded_v1` seeding pass |
| `lib/screens/settings/exercise_library_screen.dart` | Card redesign, muscle grouping, muscle chip picker in dialog |

---

## Task 1: DB Table + Migration (schema v13)

**Files:**
- Create: `lib/database/tables/exercise_muscles_table.dart`
- Modify: `lib/database/app_database.dart`

- [ ] **Step 1: Create the `ExerciseMuscles` table class**

Create `lib/database/tables/exercise_muscles_table.dart`:

```dart
import 'package:drift/drift.dart';
import 'exercises_table.dart';

class ExerciseMuscles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.cascade)();
  TextColumn get muscle => text()();
  IntColumn get sortOrder => integer()();
}
```

- [ ] **Step 2: Register table + bump schema + add migration in `app_database.dart`**

Add the import at the top of `lib/database/app_database.dart`:
```dart
import 'tables/exercise_muscles_table.dart';
```

Add `ExerciseMuscles` to the `@DriftDatabase` tables list (after `UserProfiles`):
```dart
@DriftDatabase(
  tables: [
    Exercises,
    WorkoutSessions,
    WorkoutSets,
    BodyweightEntries,
    Programs,
    ProgramPhases,
    WodTemplates,
    WodExerciseGroups,
    WodTemplateExercises,
    DailyTasks,
    DailyTaskCompletions,
    UserProfiles,
    ExerciseMuscles,   // ← add
  ],
  daos: [ ... ],  // unchanged
)
```

Change `schemaVersion` to `13`:
```dart
@override
int get schemaVersion => 13;
```

Add migration block after the existing `if (from < 12)` block:
```dart
if (from < 13) {
  final tables = await customSelect(
    'SELECT name FROM sqlite_master WHERE type="table"',
  ).get();
  final exists =
      tables.any((r) => r.read<String>('name') == 'exercise_muscles');
  if (!exists) {
    await m.createTable(exerciseMuscles);
  }
}
```

- [ ] **Step 3: Run build_runner**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
flutter pub run build_runner build --delete-conflicting-outputs 2>&1 | tail -5
```

Expected: ends with `[INFO] Succeeded after Xs.`

- [ ] **Step 4: Run flutter analyze**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
flutter analyze lib/database/ 2>&1
```

Expected: no errors in the database directory.

- [ ] **Step 5: Commit**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
git add lib/database/tables/exercise_muscles_table.dart \
        lib/database/app_database.dart \
        lib/database/app_database.g.dart
git commit -m "feat: schema v13 — add exercise_muscles table"
```

---

## Task 2: DAO Muscle Methods

**Files:**
- Modify: `lib/database/daos/exercises_dao.dart`

- [ ] **Step 1: Add `ExerciseMuscles` to the accessor and add methods**

Replace the entire contents of `lib/database/daos/exercises_dao.dart` with:

```dart
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/exercises_table.dart';
import '../tables/exercise_muscles_table.dart';

part 'exercises_dao.g.dart';

@DriftAccessor(tables: [Exercises, ExerciseMuscles])
class ExercisesDao extends DatabaseAccessor<AppDatabase>
    with _$ExercisesDaoMixin {
  ExercisesDao(super.db);

  // ── Exercises ──────────────────────────────────────────────────────────────

  Stream<List<Exercise>> watchAllExercises() =>
      (select(exercises)
        ..orderBy([(e) => OrderingTerm(expression: e.name)]))
      .watch();

  Future<List<Exercise>> getAllExercises() =>
      (select(exercises)
        ..orderBy([(e) => OrderingTerm(expression: e.name)]))
      .get();

  Future<Map<String, int>> getExerciseIdsByName() async {
    final all = await getAllExercises();
    return {for (final e in all) e.name: e.id};
  }

  Future<int> insertExercise(ExercisesCompanion entry) =>
      into(exercises).insert(entry);

  Future<bool> updateExercise(ExercisesCompanion entry) =>
      update(exercises).replace(entry);

  Future<int> deleteExercise(int id) =>
      (delete(exercises)..where((e) => e.id.equals(id))).go();

  Future<void> seedExercises(List<ExercisesCompanion> entries) async {
    await batch((b) => b.insertAllOnConflictUpdate(exercises, entries));
  }

  // ── Muscles ────────────────────────────────────────────────────────────────

  /// Returns ordered muscles for one exercise (sort_order ASC).
  Future<List<ExerciseMuscle>> getMusclesForExercise(int exerciseId) =>
      (select(exerciseMuscles)
        ..where((m) => m.exerciseId.equals(exerciseId))
        ..orderBy([(m) => OrderingTerm(expression: m.sortOrder)]))
      .get();

  /// Replaces all muscle rows for an exercise.
  Future<void> setMusclesForExercise(int exerciseId, List<String> muscles) async {
    await (delete(exerciseMuscles)
          ..where((m) => m.exerciseId.equals(exerciseId)))
        .go();
    for (int i = 0; i < muscles.length; i++) {
      await into(exerciseMuscles).insert(ExerciseMusclesCompanion(
        exerciseId: Value(exerciseId),
        muscle: Value(muscles[i]),
        sortOrder: Value(i),
      ));
    }
  }

  /// Reactive map: exerciseId → [primary, secondary, …] (sort_order ASC).
  Stream<Map<int, List<String>>> watchAllMuscleMap() =>
      (select(exerciseMuscles)
        ..orderBy([(m) => OrderingTerm(expression: m.sortOrder)]))
      .watch()
      .map((rows) {
        final map = <int, List<String>>{};
        for (final r in rows) {
          (map[r.exerciseId] ??= []).add(r.muscle);
        }
        return map;
      });
}
```

- [ ] **Step 2: Run build_runner**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
flutter pub run build_runner build --delete-conflicting-outputs 2>&1 | tail -5
```

Expected: succeeds.

- [ ] **Step 3: Run flutter analyze**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
flutter analyze lib/database/daos/exercises_dao.dart 2>&1
```

Expected: no issues.

- [ ] **Step 4: Commit**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
git add lib/database/daos/exercises_dao.dart \
        lib/database/daos/exercises_dao.g.dart
git commit -m "feat: exercises DAO — muscle CRUD + watchAllMuscleMap"
```

---

## Task 3: Constants + Provider

**Files:**
- Modify: `lib/utils/constants.dart`
- Modify: `lib/providers/exercise_providers.dart`

- [ ] **Step 1: Replace `constants.dart`**

Replace the entire contents of `lib/utils/constants.dart` with:

```dart
import 'package:drift/drift.dart';
import '../database/app_database.dart';

/// Ordered predefined muscle group list shown in the edit dialog chip grid.
const List<String> kMuscleGroups = [
  'Chest', 'Back', 'Shoulders', 'Triceps', 'Biceps',
  'Front Delt', 'Rear Delt', 'Quads', 'Hamstrings',
  'Glutes', 'Core', 'Calves', 'Full Body', 'Cardio',
];

/// exercise name → [primary muscle, ...secondary muscles]
const Map<String, List<String>> kExerciseMuscles = {
  // Chest
  'Bench Press':          ['Chest', 'Triceps', 'Front Delt'],
  'Incline Bench Press':  ['Chest', 'Triceps', 'Front Delt'],
  'Decline Bench Press':  ['Chest', 'Triceps'],
  'Dumbbell Fly':         ['Chest', 'Front Delt'],
  'Cable Fly':            ['Chest', 'Front Delt'],
  'Pec Deck':             ['Chest'],
  'Dips':                 ['Chest', 'Triceps', 'Front Delt'],
  'Push-ups':             ['Chest', 'Triceps', 'Front Delt'],
  // Back
  'Deadlift':                  ['Back', 'Glutes', 'Hamstrings', 'Core'],
  'Barbell Row':               ['Back', 'Biceps', 'Rear Delt'],
  'Pull-ups':                  ['Back', 'Biceps', 'Core'],
  'Lat Pulldown':              ['Back', 'Biceps'],
  'Seated Cable Row':          ['Back', 'Biceps', 'Rear Delt'],
  'T-Bar Row':                 ['Back', 'Biceps', 'Rear Delt'],
  'Single-Arm Dumbbell Row':   ['Back', 'Biceps'],
  'Chest-Supported Row':       ['Back', 'Rear Delt', 'Biceps'],
  'Straight-Arm Pulldown':     ['Back'],
  // Shoulders
  'Overhead Press':            ['Shoulders', 'Triceps', 'Front Delt'],
  'Dumbbell Shoulder Press':   ['Shoulders', 'Triceps', 'Front Delt'],
  'Arnold Press':              ['Shoulders', 'Triceps', 'Front Delt'],
  'Lateral Raises':            ['Shoulders'],
  'Upright Row':               ['Shoulders', 'Rear Delt', 'Biceps'],
  // Front Delt
  'Front Raise':    ['Front Delt', 'Shoulders'],
  // Rear Delt
  'Face Pulls':    ['Rear Delt', 'Shoulders'],
  'Reverse Fly':   ['Rear Delt', 'Shoulders'],
  // Triceps
  'Tricep Pushdown':           ['Triceps'],
  'Skull Crushers':            ['Triceps'],
  'Close-Grip Bench Press':    ['Triceps', 'Chest'],
  'Overhead Tricep Extension': ['Triceps'],
  'Tricep Kickback':           ['Triceps'],
  // Biceps
  'Barbell Curl':          ['Biceps'],
  'Dumbbell Curl':         ['Biceps'],
  'Hammer Curl':           ['Biceps'],
  'Preacher Curl':         ['Biceps'],
  'Cable Curl':            ['Biceps'],
  'Incline Dumbbell Curl': ['Biceps'],
  // Quads
  'Squat':                ['Quads', 'Glutes', 'Hamstrings', 'Core'],
  'Leg Press':            ['Quads', 'Glutes', 'Hamstrings'],
  'Leg Extension':        ['Quads'],
  'Lunges':               ['Quads', 'Glutes', 'Hamstrings'],
  'Hack Squat':           ['Quads', 'Glutes'],
  'Bulgarian Split Squat':['Quads', 'Glutes', 'Hamstrings'],
  'Goblet Squat':         ['Quads', 'Glutes', 'Core'],
  'Front Squat':          ['Quads', 'Glutes', 'Core'],
  // Hamstrings
  'Romanian Deadlift':  ['Hamstrings', 'Glutes', 'Back'],
  'Leg Curl':           ['Hamstrings'],
  'Nordic Curl':        ['Hamstrings', 'Glutes'],
  'Stiff-Leg Deadlift': ['Hamstrings', 'Glutes', 'Back'],
  // Glutes
  'Hip Thrust':    ['Glutes', 'Hamstrings'],
  'Glute Bridge':  ['Glutes', 'Hamstrings'],
  'Sumo Squat':    ['Glutes', 'Quads', 'Hamstrings'],
  'Cable Kickback':['Glutes'],
  // Calves
  'Calf Raises':        ['Calves'],
  'Seated Calf Raises': ['Calves'],
  // Core
  'Plank':             ['Core', 'Shoulders'],
  'Ab Wheel Rollout':  ['Core', 'Shoulders', 'Back'],
  'Cable Crunch':      ['Core'],
  'Hanging Leg Raise': ['Core'],
  'Russian Twist':     ['Core'],
  'Dead Bug':          ['Core'],
  'Side Plank':        ['Core', 'Shoulders'],
  'Decline Sit-up':    ['Core'],
  // Cardio
  'Treadmill Run':  ['Cardio'],
  'Rowing Machine': ['Cardio', 'Back'],
  'Jump Rope':      ['Cardio'],
  'Assault Bike':   ['Cardio'],
  'Stairmaster':    ['Cardio'],
  'Cycling':        ['Cardio'],
};

/// Full default exercise library (68 exercises). Inserted on first launch
/// and supplemented by the muscles_seeded_v1 pass.
final List<ExercisesCompanion> kDefaultExercises = [
  // Chest
  _ex('Bench Press'),
  _ex('Incline Bench Press'),
  _ex('Decline Bench Press'),
  _ex('Dumbbell Fly'),
  _ex('Cable Fly'),
  _ex('Pec Deck'),
  _ex('Dips'),
  _ex('Push-ups'),
  // Back
  _ex('Deadlift'),
  _ex('Barbell Row'),
  _ex('Pull-ups'),
  _ex('Lat Pulldown'),
  _ex('Seated Cable Row'),
  _ex('T-Bar Row'),
  _ex('Single-Arm Dumbbell Row'),
  _ex('Chest-Supported Row'),
  _ex('Straight-Arm Pulldown'),
  // Shoulders
  _ex('Overhead Press'),
  _ex('Dumbbell Shoulder Press'),
  _ex('Arnold Press'),
  _ex('Lateral Raises'),
  _ex('Upright Row'),
  // Front Delt
  _ex('Front Raise'),
  // Rear Delt
  _ex('Face Pulls'),
  _ex('Reverse Fly'),
  // Triceps
  _ex('Tricep Pushdown'),
  _ex('Skull Crushers'),
  _ex('Close-Grip Bench Press'),
  _ex('Overhead Tricep Extension'),
  _ex('Tricep Kickback'),
  // Biceps
  _ex('Barbell Curl'),
  _ex('Dumbbell Curl'),
  _ex('Hammer Curl'),
  _ex('Preacher Curl'),
  _ex('Cable Curl'),
  _ex('Incline Dumbbell Curl'),
  // Quads
  _ex('Squat'),
  _ex('Leg Press'),
  _ex('Leg Extension'),
  _ex('Lunges'),
  _ex('Hack Squat'),
  _ex('Bulgarian Split Squat'),
  _ex('Goblet Squat'),
  _ex('Front Squat'),
  // Hamstrings
  _ex('Romanian Deadlift'),
  _ex('Leg Curl'),
  _ex('Nordic Curl'),
  _ex('Stiff-Leg Deadlift'),
  // Glutes
  _ex('Hip Thrust'),
  _ex('Glute Bridge'),
  _ex('Sumo Squat'),
  _ex('Cable Kickback'),
  // Calves
  _ex('Calf Raises'),
  _ex('Seated Calf Raises'),
  // Core
  _ex('Plank'),
  _ex('Ab Wheel Rollout'),
  _ex('Cable Crunch'),
  _ex('Hanging Leg Raise'),
  _ex('Russian Twist'),
  _ex('Dead Bug'),
  _ex('Side Plank'),
  _ex('Decline Sit-up'),
  // Cardio (timed)
  _ex('Treadmill Run', timed: true),
  _ex('Rowing Machine', timed: true),
  _ex('Jump Rope', timed: true),
  _ex('Assault Bike', timed: true),
  _ex('Stairmaster', timed: true),
  _ex('Cycling', timed: true),
];

ExercisesCompanion _ex(String name, {bool timed = false}) =>
    ExercisesCompanion(
      name: Value(name),
      isTimed: Value(timed),
    );
```

- [ ] **Step 2: Add `exerciseMuscleMapProvider` to `exercise_providers.dart`**

Replace `lib/providers/exercise_providers.dart` with:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import 'database_provider.dart';

final exercisesProvider = StreamProvider<List<Exercise>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.exercisesDao.watchAllExercises();
});

/// Reactive map: exerciseId → [primary muscle, ...secondary muscles].
/// Empty list means no muscles assigned for that exercise.
final exerciseMuscleMapProvider =
    StreamProvider<Map<int, List<String>>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.exercisesDao.watchAllMuscleMap();
});
```

- [ ] **Step 3: Run flutter analyze**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
flutter analyze lib/utils/constants.dart lib/providers/exercise_providers.dart 2>&1
```

Expected: no issues.

- [ ] **Step 4: Commit**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
git add lib/utils/constants.dart lib/providers/exercise_providers.dart
git commit -m "feat: muscle groups constants, expanded exercise seed data, muscle map provider"
```

---

## Task 4: Seeding Pass in main.dart

**Files:**
- Modify: `lib/main.dart`

### Context

`lib/main.dart` has a `_AppStartupState._initialize()` method that already seeds exercises on first launch using the `exercises_seeded` SharedPreferences flag. The new pass uses a separate `muscles_seeded_v1` flag and runs independently so it works for both new and existing installs.

- [ ] **Step 1: Add the seeding pass after the existing `exercises_seeded` block**

In `_AppStartupState._initialize()`, after the closing `}` of the `if (!seeded)` block and before `setState(() => _ready = true)`, add:

```dart
    final musclesSeeded = prefs.getBool('muscles_seeded_v1') ?? false;
    if (!musclesSeeded) {
      final db = ref.read(databaseProvider);
      final dao = db.exercisesDao;

      // 1. Insert exercises that don't exist yet (by name).
      final existingByName = await dao.getExerciseIdsByName();
      for (final companion in kDefaultExercises) {
        final name = companion.name.value;
        if (!existingByName.containsKey(name)) {
          final newId = await dao.insertExercise(companion);
          existingByName[name] = newId;
        }
      }

      // 2. Seed muscle assignments for every exercise in kExerciseMuscles.
      for (final entry in kExerciseMuscles.entries) {
        final id = existingByName[entry.key];
        if (id != null) {
          await dao.setMusclesForExercise(id, entry.value);
        }
      }

      await prefs.setBool('muscles_seeded_v1', true);
    }
```

Make sure `kDefaultExercises` and `kExerciseMuscles` are imported. They live in `lib/utils/constants.dart`, which is already imported via `import 'utils/constants.dart';` (check top of main.dart — add this import if missing).

- [ ] **Step 2: Run flutter analyze**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
flutter analyze lib/main.dart 2>&1
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
git add lib/main.dart
git commit -m "feat: seed muscle group assignments on first launch after v13 migration"
```

---

## Task 5: Exercise Library Screen Redesign

**Files:**
- Modify: `lib/screens/settings/exercise_library_screen.dart`

### Context

The current screen has:
- `_group(List<Exercise>)` — groups by `e.category`
- `ListView.builder` rendering `_CategoryHeader` + exercise cards
- Cards: 10px vertical padding, 12px radius, `Row([name, timerIcon?, pencilIcon])`
- `_showExerciseDialog` — uses category `Autocomplete` field

### Changes

Replace the entire contents of `lib/screens/settings/exercise_library_screen.dart` with:

- [ ] **Step 1: Write the new screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../providers/exercise_providers.dart';
import '../../utils/constants.dart';
import '../../widgets/glass_background.dart';

class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState
    extends ConsumerState<ExerciseLibraryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Groups exercises by primary muscle (first entry in muscleMap).
  // Exercises with no muscles go into 'Other'.
  Map<String, List<Exercise>> _group(
    List<Exercise> exercises,
    Map<int, List<String>> muscleMap,
  ) {
    final filtered = _query.isEmpty
        ? exercises
        : exercises
            .where((e) => e.name.toLowerCase().contains(_query))
            .toList();

    final Map<String, List<Exercise>> grouped = {};
    for (final e in filtered) {
      final primary = muscleMap[e.id]?.isNotEmpty == true
          ? muscleMap[e.id]!.first
          : 'Other';
      (grouped[primary] ??= []).add(e);
    }
    return grouped;
  }

  Future<void> _showExerciseDialog({
    Exercise? existing,
    required List<Exercise> all,
    required Map<int, List<String>> muscleMap,
  }) async {
    // Load current muscles for this exercise
    List<String> initialMuscles = existing != null
        ? (muscleMap[existing.id] ?? [])
        : [];

    final nameController =
        TextEditingController(text: existing?.name ?? '')
          ..selection = TextSelection.collapsed(
              offset: existing?.name.length ?? 0);
    bool isTimed = existing?.isTimed ?? false;
    List<String> selectedMuscles = List.from(initialMuscles);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF141428),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                existing == null ? 'New Exercise' : 'Edit Exercise',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: -0.3,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name field
                    TextFormField(
                      controller: nameController,
                      autofocus: existing == null,
                      decoration: const InputDecoration(labelText: 'Name'),
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 20),

                    // Muscle groups
                    Text(
                      'MUSCLE GROUPS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to add. First = primary. Tap again to remove.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: kMuscleGroups.map((muscle) {
                        final idx = selectedMuscles.indexOf(muscle);
                        final isPrimary = idx == 0;
                        final isSelected = idx >= 0;
                        return GestureDetector(
                          onTap: () => setDialogState(() {
                            if (isSelected) {
                              selectedMuscles.remove(muscle);
                            } else {
                              selectedMuscles.add(muscle);
                            }
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(
                              color: isPrimary
                                  ? const Color(0xFF6366F1)
                                      .withValues(alpha: 0.2)
                                  : isSelected
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: isPrimary
                                    ? const Color(0xFF6366F1)
                                        .withValues(alpha: 0.5)
                                    : isSelected
                                        ? Colors.white.withValues(alpha: 0.2)
                                        : Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Text(
                              muscle,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isPrimary
                                    ? const Color(0xFFA5B4FC)
                                    : isSelected
                                        ? Colors.white.withValues(alpha: 0.75)
                                        : Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    // Selection summary
                    if (selectedMuscles.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 5,
                        children: [
                          for (int i = 0; i < selectedMuscles.length; i++)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: i == 0
                                    ? const Color(0xFF6366F1)
                                        .withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: i == 0
                                      ? const Color(0xFF6366F1)
                                          .withValues(alpha: 0.35)
                                      : Colors.white.withValues(alpha: 0.09),
                                ),
                              ),
                              child: Text(
                                i == 0
                                    ? '● ${selectedMuscles[i]}'
                                    : selectedMuscles[i],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: i == 0
                                      ? const Color(0xFF818CF8)
                                      : Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),
                    // Timed toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Timed exercise'),
                      value: isTimed,
                      onChanged: (v) => setDialogState(() => isTimed = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ValueListenableBuilder(
                  valueListenable: nameController,
                  builder: (_, __, ___) => FilledButton(
                    onPressed: nameController.text.trim().isEmpty
                        ? null
                        : () async {
                            final name = nameController.text.trim();
                            final dao =
                                ref.read(databaseProvider).exercisesDao;
                            int exerciseId;
                            if (existing == null) {
                              exerciseId =
                                  await dao.insertExercise(ExercisesCompanion(
                                name: Value(name),
                                isTimed: Value(isTimed),
                              ));
                            } else {
                              await dao.updateExercise(ExercisesCompanion(
                                id: Value(existing.id),
                                name: Value(name),
                                isTimed: Value(isTimed),
                              ));
                              exerciseId = existing.id;
                            }
                            await dao.setMusclesForExercise(
                                exerciseId, selectedMuscles);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                    child: const Text('Save'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(Exercise exercise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Exercise'),
        content: Text('Remove "${exercise.name}" from the library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(databaseProvider)
          .exercisesDao
          .deleteExercise(exercise.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesProvider);
    final muscleMapAsync = ref.watch(exerciseMuscleMapProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Exercise Library')),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search exercises…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: exercisesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (exercises) {
                    final muscleMap =
                        muscleMapAsync.valueOrNull ?? {};
                    final grouped = _group(exercises, muscleMap);
                    if (grouped.isEmpty) {
                      return Center(
                        child: Text(
                          _query.isEmpty
                              ? 'No exercises yet. Tap + to add one.'
                              : 'No results for "$_query"',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                              ),
                        ),
                      );
                    }
                    // Sort groups: kMuscleGroups order first, then 'Other'
                    final groupOrder = [...kMuscleGroups, 'Other'];
                    final categories = grouped.keys.toList()
                      ..sort((a, b) {
                        final ai = groupOrder.indexOf(a);
                        final bi = groupOrder.indexOf(b);
                        final ai2 = ai < 0 ? groupOrder.length : ai;
                        final bi2 = bi < 0 ? groupOrder.length : bi;
                        return ai2.compareTo(bi2);
                      });

                    return ListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(16, 4, 16, 88),
                      itemCount: categories.fold<int>(
                        0,
                        (sum, cat) => sum + 1 + grouped[cat]!.length,
                      ),
                      itemBuilder: (_, index) {
                        var remaining = index;
                        for (final cat in categories) {
                          if (remaining == 0) {
                            return _MuscleGroupHeader(
                              label: cat,
                              count: grouped[cat]!.length,
                            );
                          }
                          remaining--;
                          final items = grouped[cat]!;
                          if (remaining < items.length) {
                            final exercise = items[remaining];
                            final muscles = muscleMap[exercise.id] ?? [];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _showExerciseDialog(
                                    existing: exercise,
                                    all: exercises,
                                    muscleMap: muscleMap,
                                  ),
                                  onLongPress: () =>
                                      _confirmDelete(exercise),
                                  borderRadius:
                                      BorderRadius.circular(16),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: 0.05),
                                      borderRadius:
                                          BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.09),
                                        width: 1.5,
                                      ),
                                    ),
                                    padding:
                                        const EdgeInsets.fromLTRB(
                                            14, 13, 14, 11),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Name row
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                exercise.name,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  letterSpacing: -0.2,
                                                ),
                                              ),
                                            ),
                                            if (exercise.isTimed) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                          0xFF6366F1)
                                                      .withValues(
                                                          alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(6),
                                                  border: Border.all(
                                                    color: const Color(
                                                            0xFF6366F1)
                                                        .withValues(
                                                            alpha: 0.2),
                                                  ),
                                                ),
                                                child: const Text(
                                                  'TIMED',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color:
                                                        Color(0xFF818CF8),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        // Muscle chips
                                        if (muscles.isNotEmpty) ...[
                                          const SizedBox(height: 7),
                                          Wrap(
                                            spacing: 5,
                                            runSpacing: 4,
                                            children: [
                                              for (int i = 0;
                                                  i < muscles.length;
                                                  i++)
                                                Container(
                                                  padding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8,
                                                          vertical: 3),
                                                  decoration:
                                                      BoxDecoration(
                                                    color: i == 0
                                                        ? const Color(
                                                                0xFF6366F1)
                                                            .withValues(
                                                                alpha:
                                                                    0.15)
                                                        : Colors.white
                                                            .withValues(
                                                                alpha:
                                                                    0.05),
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(7),
                                                    border: Border.all(
                                                      color: i == 0
                                                          ? const Color(
                                                                  0xFF6366F1)
                                                              .withValues(
                                                                  alpha:
                                                                      0.28)
                                                          : Colors.white
                                                              .withValues(
                                                                  alpha:
                                                                      0.09),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    muscles[i],
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: i == 0
                                                          ? FontWeight.w700
                                                          : FontWeight.w600,
                                                      color: i == 0
                                                          ? const Color(
                                                              0xFF818CF8)
                                                          : Colors.white
                                                              .withValues(
                                                                  alpha:
                                                                      0.38),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          remaining -= items.length;
                        }
                        return const SizedBox.shrink();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: exercisesAsync.whenOrNull(
        data: (exercises) => FloatingActionButton(
          onPressed: () => _showExerciseDialog(
            all: exercises,
            muscleMap: muscleMapAsync.valueOrNull ?? {},
          ),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _MuscleGroupHeader extends StatelessWidget {
  const _MuscleGroupHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run flutter analyze**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
flutter analyze lib/screens/settings/exercise_library_screen.dart 2>&1
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
git add lib/screens/settings/exercise_library_screen.dart
git commit -m "feat: exercise library — bigger cards, muscle chips, muscle group picker dialog"
```

---

## Task 6: Manual Verification

- [ ] **Step 1: Run the app**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
flutter run
```

- [ ] **Step 2: Verify seeding**
  - Open Exercise Library — exercises should be grouped by muscle group (Chest, Back, Shoulders, etc.)
  - Each card should show the exercise name + muscle chips below
  - Cardio exercises (Treadmill Run etc.) should show the TIMED chip

- [ ] **Step 3: Verify card design**
  - Cards are visibly taller than before
  - No pencil icon on any card
  - Primary muscle chip is indigo; secondary chips are dim white
  - Tapping a card opens the edit dialog

- [ ] **Step 4: Verify edit dialog**
  - Open any exercise — muscle chips should be pre-selected
  - Tap a selected chip to remove it; the next one becomes primary
  - Tap an unselected chip to add it
  - Summary badges below the grid show current order (first = "● Name")
  - Save and verify card updates

- [ ] **Step 5: Verify new exercise creation**
  - Tap +, type a name, select muscles, save
  - New exercise appears under the correct primary muscle group

- [ ] **Step 6: Final flutter analyze**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
flutter analyze 2>&1
```

Expected: no new errors.
