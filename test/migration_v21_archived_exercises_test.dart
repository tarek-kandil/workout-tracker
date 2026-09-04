import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:workout_tracker/database/app_database.dart';

/// Schema v20 -> v21 migration test — non-destructive exercise deletion.
///
/// Adds a single additive `archived` column (BOOLEAN, default false) to
/// exercises. Seeds a realistic pre-v21 database (default exercises, a
/// custom exercise, exercise_muscles rows, a workout_sessions/workout_sets
/// history, and a wod_template_exercises reference) and verifies:
///   - the new `archived` column exists after migration
///   - it defaults to false (0) for every pre-existing row
///   - nothing is lost (every exercise/exercise_muscles/session/set row
///     present before migration is still present after)
///   - the migration is idempotent on a fresh v21 database
const _createExercisesV20 = '''
  CREATE TABLE exercises (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Other',
    notes TEXT,
    is_timed INTEGER NOT NULL DEFAULT 0,
    muscle_needs_review INTEGER NOT NULL DEFAULT 0,
    muscle_review_note TEXT
  );
''';

const _createExerciseMusclesV20 = '''
  CREATE TABLE exercise_muscles (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    exercise_id INTEGER NOT NULL,
    muscle TEXT NOT NULL,
    sort_order INTEGER NOT NULL,
    role TEXT NOT NULL DEFAULT 'primary',
    is_active INTEGER NOT NULL DEFAULT 1
  );
''';

const _createWorkoutSessionsV20 = '''
  CREATE TABLE workout_sessions (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    date INTEGER NOT NULL,
    workout_name TEXT NOT NULL,
    wod_template_id INTEGER,
    week_number INTEGER,
    notes TEXT
  );
''';

const _createWorkoutSetsV20 = '''
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

const _createWodTemplateExercisesV20 = '''
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
    raw.execute(_createExercisesV20);
    raw.execute(_createExerciseMusclesV20);
    raw.execute(_createWorkoutSessionsV20);
    raw.execute(_createWorkoutSetsV20);
    raw.execute(_createWodTemplateExercisesV20);

    raw.execute('''
      INSERT INTO exercises (id, name, category, is_timed) VALUES
        (1, 'Bench Press', 'Chest', 0),
        (2, 'Pull-Up', 'Back', 0),
        (3, 'Custom Curl', 'Other', 0);
    ''');
    raw.execute('''
      INSERT INTO exercise_muscles (id, exercise_id, muscle, sort_order, role, is_active) VALUES
        (1, 1, 'Chest', 0, 'primary', 1),
        (2, 2, 'Lats', 0, 'primary', 1);
    ''');
    raw.execute('''
      INSERT INTO workout_sessions (id, date, workout_name) VALUES
        (1, 1750000000, 'Push Day');
    ''');
    raw.execute('''
      INSERT INTO workout_sets
        (id, session_id, exercise_id, set_number, reps, weight_kg) VALUES
        (1, 1, 1, 1, 8, 60.0);
    ''');
    raw.execute('''
      INSERT INTO wod_template_exercises
        (id, wod_template_id, exercise_id, sort_order) VALUES
        (1, 1, 2, 1);
    ''');

    raw.execute('PRAGMA user_version = 20;');
  });

  test('v20 -> v21 adds an archived column defaulting to false', () async {
    final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get(); // force migration

    final cols = await db.customSelect('PRAGMA table_info(exercises)').get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names, contains('archived'));

    final rows =
        await db.customSelect('SELECT id, archived FROM exercises').get();
    expect(rows, hasLength(3));
    for (final r in rows) {
      expect(r.read<bool>('archived'), isFalse);
    }
  });

  test('v20 -> v21 preserves every row (exercises, muscles, sessions, sets, template refs)',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    final exerciseRows =
        await db.customSelect('SELECT id FROM exercises').get();
    expect(exerciseRows, hasLength(3));

    final muscleRows =
        await db.customSelect('SELECT id FROM exercise_muscles').get();
    expect(muscleRows, hasLength(2));

    final sessionRows =
        await db.customSelect('SELECT id FROM workout_sessions').get();
    expect(sessionRows, hasLength(1));

    final setRows = await db.customSelect('SELECT id FROM workout_sets').get();
    expect(setRows, hasLength(1));

    final templateRefRows = await db
        .customSelect('SELECT id FROM wod_template_exercises')
        .get();
    expect(templateRefRows, hasLength(1));
  });

  test('v21 migration is idempotent on a fresh v21 database', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    final cols = await db.customSelect('PRAGMA table_info(exercises)').get();
    expect(cols.map((r) => r.read<String>('name')), contains('archived'));
  });
}
