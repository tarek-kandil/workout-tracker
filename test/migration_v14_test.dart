import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:workout_tracker/database/app_database.dart';

/// Regression test for issue #5: editing weights/reps crashed with a red screen
/// because the on-device `workout_sets` table pre-dated the `rpe`/`notes`
/// columns and no migration added them. Schema v14 backfills them.
void main() {
  test('v13 -> v14 adds missing rpe/notes columns and allows writing them',
      () async {
    final raw = sqlite3.openInMemory();

    // Simulate an old device: workout_sets without rpe / notes columns, and no
    // foreign-key clauses so we can seed a row without the related tables.
    raw.execute('''
      CREATE TABLE workout_sets (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        exercise_id INTEGER NOT NULL,
        set_number INTEGER NOT NULL,
        reps INTEGER NOT NULL,
        weight_kg REAL NOT NULL,
        duration_seconds INTEGER
      );
    ''');
    raw.execute(
      'INSERT INTO workout_sets '
      '(id, session_id, exercise_id, set_number, reps, weight_kg, duration_seconds) '
      'VALUES (1, 1, 1, 1, 5, 100.0, NULL);',
    );
    raw.execute('PRAGMA user_version = 13;');

    final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(db.close);

    // Force the migration to run.
    await db.customSelect('SELECT 1').get();

    final cols = await db
        .customSelect('PRAGMA table_info(workout_sets)')
        .get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names, contains('rpe'));
    expect(names, contains('notes'));

    // The failing operation from #5: writing rpe + notes must now succeed.
    await db.setsDao.updateSet(WorkoutSetsCompanion(
      id: const Value(1),
      sessionId: const Value(1),
      exerciseId: const Value(1),
      setNumber: const Value(1),
      reps: const Value(8),
      weightKg: const Value(102.5),
      durationSeconds: const Value(null),
      rpe: const Value(8.5),
      notes: const Value('felt strong'),
    ));

    final row = await db
        .customSelect('SELECT rpe, notes, reps FROM workout_sets WHERE id = 1')
        .getSingle();
    expect(row.read<double>('rpe'), 8.5);
    expect(row.read<String>('notes'), 'felt strong');
    expect(row.read<int>('reps'), 8);
  });

  test('migration is idempotent when columns already exist', () async {
    // Fresh schema-14 database (onCreate already includes rpe/notes); opening
    // again must not error.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    final cols =
        await db.customSelect('PRAGMA table_info(workout_sets)').get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names, containsAll(<String>['rpe', 'notes']));
  });
}
