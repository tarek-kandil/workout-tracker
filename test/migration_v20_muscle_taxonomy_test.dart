import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:workout_tracker/database/app_database.dart';

/// Schema v19 -> v20 migration test — Muscle Taxonomy + Weekly Volume
/// Report (specs/003-muscle-volume-report).
///
/// Seeds a realistic pre-v20 database: default exercises with broad legacy
/// muscle tags (exact 1:1, singular Front Delt, ambiguous Back/Core, Full
/// Body with and without a remaining muscle, default vs. custom Cardio), a
/// custom (user-created) exercise, a circuit (wod_exercise_groups +
/// wod_template_exercises), and workout_sessions/workout_sets rows
/// (including rir values). Migrates to v20 and asserts:
///   - nothing is lost (every exercise/exercise_muscles/session/set/circuit
///     row present before migration is still present after)
///   - `role` is populated from the old sortOrder==0-is-primary convention
///   - exact 1:1 tags are kept active and unflagged
///   - singular Front Delt is safely renamed, unflagged
///   - ambiguous Back/Core are best-guess mapped (Lats/Abs) and flagged
///     "needs review"
///   - Full Body/Cardio are deactivated; flagged only when no other active
///     taxonomy muscle remains (and never for default cardio exercises)
///   - the migration is idempotent on a fresh v20 database
const _createExercisesV19 = '''
  CREATE TABLE exercises (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Other',
    notes TEXT,
    is_timed INTEGER NOT NULL DEFAULT 0
  );
''';

const _createExerciseMusclesV19 = '''
  CREATE TABLE exercise_muscles (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    exercise_id INTEGER NOT NULL,
    muscle TEXT NOT NULL,
    sort_order INTEGER NOT NULL
  );
''';

const _createWorkoutSessionsV19 = '''
  CREATE TABLE workout_sessions (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    date INTEGER NOT NULL,
    workout_name TEXT NOT NULL,
    wod_template_id INTEGER,
    week_number INTEGER,
    notes TEXT
  );
''';

const _createWorkoutSetsV19 = '''
  CREATE TABLE workout_sets (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER NOT NULL,
    exercise_id INTEGER NOT NULL,
    set_number INTEGER NOT NULL,
    reps INTEGER NOT NULL,
    weight_kg REAL NOT NULL,
    duration_seconds INTEGER,
    rpe REAL,
    rir REAL,
    notes TEXT
  );
''';

const _createWodTemplatesV19 = '''
  CREATE TABLE wod_templates (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    phase_id INTEGER NOT NULL,
    wod_number INTEGER NOT NULL,
    name TEXT NOT NULL,
    notes TEXT,
    rest_seconds INTEGER NOT NULL DEFAULT 90
  );
''';

const _createWodExerciseGroupsV19 = '''
  CREATE TABLE wod_exercise_groups (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    wod_template_id INTEGER NOT NULL,
    sort_order INTEGER NOT NULL,
    name TEXT,
    rounds INTEGER NOT NULL DEFAULT 3,
    rest_between_exercises_seconds INTEGER NOT NULL DEFAULT 0,
    rest_between_rounds_seconds INTEGER NOT NULL DEFAULT 90
  );
''';

const _createWodTemplateExercisesV19 = '''
  CREATE TABLE wod_template_exercises (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    wod_template_id INTEGER NOT NULL,
    exercise_id INTEGER NOT NULL,
    sort_order INTEGER NOT NULL,
    group_id INTEGER,
    target_sets INTEGER NOT NULL DEFAULT 3,
    rep_range_min INTEGER NOT NULL DEFAULT 6,
    rep_range_max INTEGER NOT NULL DEFAULT 12,
    notes TEXT,
    rest_seconds INTEGER,
    rest_between_sets_seconds INTEGER,
    target_rpe REAL,
    target_rir REAL,
    video_url TEXT
  );
''';

void main() {
  late Database raw;

  setUp(() {
    raw = sqlite3.openInMemory();
    raw.execute(_createExercisesV19);
    raw.execute(_createExerciseMusclesV19);
    raw.execute(_createWorkoutSessionsV19);
    raw.execute(_createWorkoutSetsV19);
    raw.execute(_createWodTemplatesV19);
    raw.execute(_createWodExerciseGroupsV19);
    raw.execute(_createWodTemplateExercisesV19);

    // ── Exercises ──────────────────────────────────────────────────────
    raw.execute('''
      INSERT INTO exercises (id, name, category, is_timed) VALUES
        (1, 'Bench Press', 'Chest', 0),
        (2, 'Pull-Up', 'Back', 0),
        (3, 'Standing Ab Crunch', 'Core', 0),
        (4, 'Kettlebell Swing', 'Legs', 0),
        (5, 'Front Squat', 'Legs', 0),
        (6, 'Battle Ropes', 'Full Body', 0),
        (7, 'Farmer''s Carry', 'Full Body', 0),
        (8, 'Treadmill Run', 'Cardio', 1),
        (9, 'Sled Push', 'Cardio', 0);
    ''');
    // Exercise 3 ("Standing Ab Crunch") is the custom/user-created exercise
    // in this scenario — same table shape as a default exercise, since
    // "custom" is a UI/seeding distinction, not a schema one.

    // ── Legacy broad-tag ExerciseMuscles rows ───────────────────────────
    raw.execute('''
      INSERT INTO exercise_muscles (id, exercise_id, muscle, sort_order) VALUES
        -- exact 1:1 tags: Chest (primary) + Triceps (secondary)
        (1, 1, 'Chest', 0),
        (2, 1, 'Triceps', 1),
        -- ambiguous: Back
        (3, 2, 'Back', 0),
        -- ambiguous: Core (on the custom exercise)
        (4, 3, 'Core', 0),
        -- exact 1:1 tag used inside a circuit exercise
        (5, 4, 'Glutes', 0),
        -- mixed: exact primary (Quads) + singular safe-rename secondary
        (6, 5, 'Quads', 0),
        (7, 5, 'Front Delt', 1),
        -- Full Body only -> no remaining active taxonomy muscle -> flagged
        (8, 6, 'Full Body', 0),
        -- Full Body + a remaining exact taxonomy muscle -> NOT flagged
        (9, 7, 'Full Body', 0),
        (10, 7, 'Forearms', 1),
        -- default cardio exercise -> never flagged
        (11, 8, 'Cardio', 0),
        -- non-default cardio-tagged exercise, no other muscle -> flagged
        (12, 9, 'Cardio', 0);
    ''');

    // ── A circuit: one wod_template, one group (rounds), one member ────
    raw.execute('''
      INSERT INTO wod_templates (id, phase_id, wod_number, name) VALUES
        (1, 1, 1, 'Full Body Circuit');
    ''');
    raw.execute('''
      INSERT INTO wod_exercise_groups
        (id, wod_template_id, sort_order, name, rounds) VALUES
        (1, 1, 1, 'Circuit A', 3);
    ''');
    raw.execute('''
      INSERT INTO wod_template_exercises
        (id, wod_template_id, exercise_id, sort_order, group_id) VALUES
        (1, 1, 4, 1, 1);
    ''');

    // ── A session with straight sets (rir values) + circuit sets ───────
    raw.execute('''
      INSERT INTO workout_sessions (id, date, workout_name, wod_template_id) VALUES
        (1, 1750000000, 'Full Body Circuit', 1);
    ''');
    raw.execute('''
      INSERT INTO workout_sets
        (id, session_id, exercise_id, set_number, reps, weight_kg, rir) VALUES
        (1, 1, 1, 1, 8, 60.0, 2.0),
        (2, 1, 1, 2, 8, 60.0, NULL),
        (3, 1, 4, 1, 15, 16.0, 5.0),
        (4, 1, 4, 2, 15, 16.0, 5.0);
    ''');

    raw.execute('PRAGMA user_version = 19;');
  });

  test(
    'v19 -> v20 preserves every row (exercises, muscles, sessions, sets, circuit)',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get(); // force migration

      final exerciseRows =
          await db.customSelect('SELECT id FROM exercises').get();
      expect(exerciseRows, hasLength(9));

      // No exercise_muscles row is ever deleted — legacy rows persist as
      // is_active = 0 alongside any newly-inserted mapped rows.
      final muscleRows =
          await db.customSelect('SELECT id FROM exercise_muscles').get();
      expect(muscleRows.length, greaterThanOrEqualTo(12));

      final sessionRows =
          await db.customSelect('SELECT id FROM workout_sessions').get();
      expect(sessionRows, hasLength(1));

      final setRows =
          await db.customSelect('SELECT id, rir FROM workout_sets').get();
      expect(setRows, hasLength(4));
      final byId = {for (final r in setRows) r.read<int>('id'): r};
      expect(byId[1]!.read<double?>('rir'), 2.0);
      expect(byId[2]!.read<double?>('rir'), isNull);
      expect(byId[3]!.read<double?>('rir'), 5.0);

      final circuitRows = await db
          .customSelect('SELECT id FROM wod_exercise_groups')
          .get();
      expect(circuitRows, hasLength(1));
      final circuitMemberRows = await db
          .customSelect('SELECT id, group_id FROM wod_template_exercises')
          .get();
      expect(circuitMemberRows, hasLength(1));
      expect(circuitMemberRows.single.read<int?>('group_id'), 1);
    },
  );

  test('v19 -> v20 adds role/is_active/muscle_needs_review columns', () async {
    final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    final emCols =
        await db.customSelect('PRAGMA table_info(exercise_muscles)').get();
    final emNames = emCols.map((r) => r.read<String>('name')).toSet();
    expect(emNames, containsAll(<String>['role', 'is_active']));

    final exCols = await db.customSelect('PRAGMA table_info(exercises)').get();
    final exNames = exCols.map((r) => r.read<String>('name')).toSet();
    expect(exNames, containsAll(<String>['muscle_needs_review', 'muscle_review_note']));
  });

  test('v19 -> v20 populates role from the sortOrder==0-is-primary convention',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(db.close);

    final chest = (await db.exercisesDao.getMusclesForExercise(1))
        .firstWhere((m) => m.muscle == 'Chest');
    final triceps = (await db.exercisesDao.getMusclesForExercise(1))
        .firstWhere((m) => m.muscle == 'Triceps');
    expect(chest.role, 'primary');
    expect(triceps.role, 'secondary');
  });

  test('v19 -> v20 keeps exact 1:1 tags active and unflagged', () async {
    final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(db.close);

    final musclesForBench = await db.exercisesDao.getMusclesForExercise(1);
    expect(musclesForBench.map((m) => m.muscle), containsAll(<String>['Chest', 'Triceps']));

    final bench =
        (await db.exercisesDao.getAllExercises()).firstWhere((e) => e.id == 1);
    expect(bench.muscleNeedsReview, isFalse);
  });

  test('v19 -> v20 safely renames singular Front Delt without a review flag',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(db.close);

    final musclesForSquat = await db.exercisesDao.getMusclesForExercise(5);
    final muscleNames = musclesForSquat.map((m) => m.muscle).toSet();
    expect(muscleNames, contains('Quads'));
    expect(muscleNames, contains('Front Delts'));
    expect(muscleNames, isNot(contains('Front Delt')));

    final squat =
        (await db.exercisesDao.getAllExercises()).firstWhere((e) => e.id == 5);
    expect(squat.muscleNeedsReview, isFalse);

    final quads = musclesForSquat.firstWhere((m) => m.muscle == 'Quads');
    final frontDelts =
        musclesForSquat.firstWhere((m) => m.muscle == 'Front Delts');
    expect(quads.role, 'primary');
    expect(frontDelts.role, 'secondary');
  });

  test('v19 -> v20 best-guess maps ambiguous Back -> Lats and flags for review',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(db.close);

    final musclesForPullUp = await db.exercisesDao.getMusclesForExercise(2);
    expect(musclesForPullUp.map((m) => m.muscle), ['Lats']);
    expect(musclesForPullUp.single.role, 'primary');

    final pullUp =
        (await db.exercisesDao.getAllExercises()).firstWhere((e) => e.id == 2);
    expect(pullUp.muscleNeedsReview, isTrue);
    expect(pullUp.muscleReviewNote, contains('Back'));
  });

  test(
      'v19 -> v20 best-guess maps ambiguous Core -> Abs and flags the custom exercise for review',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(db.close);

    final musclesForCustom = await db.exercisesDao.getMusclesForExercise(3);
    expect(musclesForCustom.map((m) => m.muscle), ['Abs']);

    final custom =
        (await db.exercisesDao.getAllExercises()).firstWhere((e) => e.id == 3);
    expect(custom.muscleNeedsReview, isTrue);
    expect(custom.muscleReviewNote, contains('Core'));
  });

  test(
      'v19 -> v20 flags Full Body exercises for review only when no active taxonomy muscle remains',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(db.close);

    final allExercises = await db.exercisesDao.getAllExercises();

    // Battle Ropes: Full Body only -> no remaining active muscle -> flagged.
    final battleRopes = allExercises.firstWhere((e) => e.id == 6);
    expect(battleRopes.muscleNeedsReview, isTrue);
    final battleRopesMuscles = await db.exercisesDao.getMusclesForExercise(6);
    expect(battleRopesMuscles, isEmpty);

    // Farmer's Carry: Full Body + Forearms -> Forearms remains active -> not flagged.
    final farmersCarry = allExercises.firstWhere((e) => e.id == 7);
    expect(farmersCarry.muscleNeedsReview, isFalse);
    final farmersCarryMuscles = await db.exercisesDao.getMusclesForExercise(7);
    expect(farmersCarryMuscles.map((m) => m.muscle), ['Forearms']);
  });

  test(
      'v19 -> v20 never flags default cardio exercises but flags non-default Cardio-tagged exercises',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(db.close);

    final allExercises = await db.exercisesDao.getAllExercises();

    final treadmill = allExercises.firstWhere((e) => e.id == 8);
    expect(treadmill.muscleNeedsReview, isFalse);

    final sledPush = allExercises.firstWhere((e) => e.id == 9);
    expect(sledPush.muscleNeedsReview, isTrue);
  });

  test('v20 migration is idempotent on a fresh v20 database', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    final emCols =
        await db.customSelect('PRAGMA table_info(exercise_muscles)').get();
    expect(emCols.map((r) => r.read<String>('name')),
        containsAll(<String>['role', 'is_active']));

    final exCols = await db.customSelect('PRAGMA table_info(exercises)').get();
    expect(exCols.map((r) => r.read<String>('name')),
        containsAll(<String>['muscle_needs_review', 'muscle_review_note']));
  });
}
