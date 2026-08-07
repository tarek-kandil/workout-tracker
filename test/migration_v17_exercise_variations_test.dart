import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:workout_tracker/database/app_database.dart';

const _createExercises = '''
  CREATE TABLE exercises (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 100),
    category TEXT NOT NULL DEFAULT 'Other',
    notes TEXT NULL,
    is_timed INTEGER NOT NULL DEFAULT 0 CHECK (is_timed IN (0, 1))
  );
''';

void main() {
  test(
    'v15 -> v17 creates exercise_variations and exposes symmetric links',
    () async {
      final raw = sqlite3.openInMemory();
      raw.execute(_createExercises);
      raw.execute(
        "INSERT INTO exercises (id, name, category, notes, is_timed) VALUES "
        "(1, 'Bench Press', 'Strength', NULL, 0), "
        "(2, 'Dumbbell Press', 'Strength', NULL, 0);",
      );
      raw.execute('PRAGMA user_version = 15;');

      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      await db.customSelect('SELECT 1').get();

      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'exercise_variations'",
          )
          .get();
      expect(tables, hasLength(1));

      await db.exerciseVariationsDao.addVariation(1, 2);
      await db.exerciseVariationsDao.addVariation(2, 1);

      final benchVariations = await db.exerciseVariationsDao.getVariations(1);
      final dumbbellVariations =
          await db.exerciseVariationsDao.getVariations(2);
      expect(benchVariations.single.name, 'Dumbbell Press');
      expect(dumbbellVariations.single.name, 'Bench Press');
    },
  );

  test(
    'v16 -> v17 renames exercise_sisters to exercise_variations, keeping data',
    () async {
      final raw = sqlite3.openInMemory();
      raw.execute(_createExercises);
      raw.execute('''
        CREATE TABLE exercise_sisters (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          exercise_id INTEGER NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
          sister_exercise_id INTEGER NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
          UNIQUE (exercise_id, sister_exercise_id)
        );
      ''');
      raw.execute(
        "INSERT INTO exercises (id, name, category, notes, is_timed) VALUES "
        "(1, 'Squat', 'Strength', NULL, 0), "
        "(2, 'Leg Press', 'Strength', NULL, 0);",
      );
      raw.execute(
        "INSERT INTO exercise_sisters (exercise_id, sister_exercise_id) "
        "VALUES (1, 2);",
      );
      raw.execute('PRAGMA user_version = 16;');

      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      await db.customSelect('SELECT 1').get();

      // Old table gone, new table present.
      final oldTable = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'exercise_sisters'",
          )
          .get();
      expect(oldTable, isEmpty);

      // Existing link preserved and exposed under the new API/column name.
      final variations = await db.exerciseVariationsDao.getVariations(1);
      expect(variations.single.name, 'Leg Press');
    },
  );

  test(
    'v17 migration is idempotent when exercise_variations already exists',
    () async {
      final raw = sqlite3.openInMemory();
      raw.execute(_createExercises);
      raw.execute('''
        CREATE TABLE exercise_variations (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          exercise_id INTEGER NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
          variation_exercise_id INTEGER NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
          UNIQUE (exercise_id, variation_exercise_id)
        );
      ''');
      raw.execute(
        "INSERT INTO exercises (id, name, category, notes, is_timed) VALUES "
        "(1, 'Deadlift', 'Strength', NULL, 0), "
        "(2, 'Romanian Deadlift', 'Strength', NULL, 0);",
      );
      raw.execute('PRAGMA user_version = 16;');

      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      await db.customSelect('SELECT 1').get();
      await db.exerciseVariationsDao.addVariation(1, 2);

      final variations = await db.exerciseVariationsDao.getVariations(2);
      expect(variations.single.name, 'Deadlift');
    },
  );
}
