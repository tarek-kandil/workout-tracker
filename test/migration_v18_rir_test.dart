import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:workout_tracker/database/app_database.dart';

/// Schema v18 migration test — RPE → RIR (additive, keeps the old rpe /
/// targetRpe columns for one release). RIR = 10 − RPE.
///
/// Seeds a v17 workout_sets + wod_template_exercises schema with rpe /
/// targetRpe rows (including nulls) and verifies:
///   - rir == 10 - rpe for each non-null value (exact, 0.5 granularity)
///   - nulls stay null (not distorted)
///   - the old rpe / targetRpe columns are unchanged
///   - row counts are preserved
const _createWorkoutSets = '''
  CREATE TABLE workout_sets (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER NOT NULL,
    exercise_id INTEGER NOT NULL,
    set_number INTEGER NOT NULL,
    reps INTEGER NOT NULL,
    weight_kg REAL NOT NULL,
    duration_seconds INTEGER,
    rpe REAL,
    notes TEXT
  );
''';

const _createWodTemplateExercises = '''
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
    video_url TEXT
  );
''';

void main() {
  test(
    'v17 -> v18 backfills rir = 10 - rpe on workout_sets, preserving rpe and nulls',
    () async {
      final raw = sqlite3.openInMemory();
      raw.execute(_createWorkoutSets);
      raw.execute(_createWodTemplateExercises); // touched by the same migration step
      raw.execute(
        'INSERT INTO workout_sets '
        '(id, session_id, exercise_id, set_number, reps, weight_kg, rpe) VALUES '
        '(1, 1, 1, 1, 5, 100.0, NULL), '
        '(2, 1, 1, 2, 5, 100.0, 10.0), '
        '(3, 1, 1, 3, 5, 100.0, 9.5), '
        '(4, 1, 1, 4, 5, 100.0, 8.0), '
        '(5, 1, 1, 5, 5, 100.0, 6.0);',
      );
      raw.execute('PRAGMA user_version = 17;');

      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      // Force the migration to run.
      await db.customSelect('SELECT 1').get();

      final cols =
          await db.customSelect('PRAGMA table_info(workout_sets)').get();
      final names = cols.map((r) => r.read<String>('name')).toSet();
      expect(names, contains('rir'));
      expect(names, contains('rpe')); // old column kept for one release

      final rows = await db.customSelect(
        'SELECT id, rpe, rir FROM workout_sets ORDER BY id',
      ).get();
      expect(rows, hasLength(5)); // row count preserved

      final byId = {for (final r in rows) r.read<int>('id'): r};

      expect(byId[1]!.read<double?>('rpe'), isNull);
      expect(byId[1]!.read<double?>('rir'), isNull); // null stays null

      expect(byId[2]!.read<double?>('rpe'), 10.0); // old column unchanged
      expect(byId[2]!.read<double?>('rir'), 0.0);

      expect(byId[3]!.read<double?>('rpe'), 9.5);
      expect(byId[3]!.read<double?>('rir'), 0.5);

      expect(byId[4]!.read<double?>('rpe'), 8.0);
      expect(byId[4]!.read<double?>('rir'), 2.0);

      expect(byId[5]!.read<double?>('rpe'), 6.0);
      expect(byId[5]!.read<double?>('rir'), 4.0);
    },
  );

  test(
    'v17 -> v18 backfills target_rir = 10 - target_rpe on wod_template_exercises',
    () async {
      final raw = sqlite3.openInMemory();
      raw.execute(_createWorkoutSets); // touched by the same migration step
      raw.execute(_createWodTemplateExercises);
      raw.execute(
        'INSERT INTO wod_template_exercises '
        '(id, wod_template_id, exercise_id, sort_order, target_rpe) VALUES '
        '(1, 1, 1, 1, NULL), '
        '(2, 1, 1, 2, 10.0), '
        '(3, 1, 1, 3, 9.5), '
        '(4, 1, 1, 4, 8.0), '
        '(5, 1, 1, 5, 6.0);',
      );
      raw.execute('PRAGMA user_version = 17;');

      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      await db.customSelect('SELECT 1').get();

      final cols = await db
          .customSelect('PRAGMA table_info(wod_template_exercises)')
          .get();
      final names = cols.map((r) => r.read<String>('name')).toSet();
      expect(names, contains('target_rir'));
      expect(names, contains('target_rpe'));

      final rows = await db.customSelect(
        'SELECT id, target_rpe, target_rir FROM wod_template_exercises ORDER BY id',
      ).get();
      expect(rows, hasLength(5));

      final byId = {for (final r in rows) r.read<int>('id'): r};

      expect(byId[1]!.read<double?>('target_rpe'), isNull);
      expect(byId[1]!.read<double?>('target_rir'), isNull);

      expect(byId[2]!.read<double?>('target_rpe'), 10.0);
      expect(byId[2]!.read<double?>('target_rir'), 0.0);

      expect(byId[3]!.read<double?>('target_rpe'), 9.5);
      expect(byId[3]!.read<double?>('target_rir'), 0.5);

      expect(byId[4]!.read<double?>('target_rpe'), 8.0);
      expect(byId[4]!.read<double?>('target_rir'), 2.0);

      expect(byId[5]!.read<double?>('target_rpe'), 6.0);
      expect(byId[5]!.read<double?>('target_rir'), 4.0);
    },
  );

  test('v18 migration is idempotent when rir/target_rir already exist', () async {
    // Fresh schema-18 database (onCreate already includes rir/target_rir);
    // opening again must not error.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    final setsCols =
        await db.customSelect('PRAGMA table_info(workout_sets)').get();
    expect(setsCols.map((r) => r.read<String>('name')), contains('rir'));

    final teCols = await db
        .customSelect('PRAGMA table_info(wod_template_exercises)')
        .get();
    expect(teCols.map((r) => r.read<String>('name')), contains('target_rir'));
  });
}
