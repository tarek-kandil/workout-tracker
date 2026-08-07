import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:workout_tracker/database/app_database.dart';

void main() {
  test(
    'v15 -> v16 creates exercise_sisters and exposes symmetric links',
    () async {
      final raw = sqlite3.openInMemory();
      raw.execute('''
      CREATE TABLE exercises (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 100),
        category TEXT NOT NULL DEFAULT 'Other',
        notes TEXT NULL,
        is_timed INTEGER NOT NULL DEFAULT 0 CHECK (is_timed IN (0, 1))
      );
    ''');
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
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'exercise_sisters'",
          )
          .get();
      expect(tables, hasLength(1));

      await db.exerciseSistersDao.addSister(1, 2);
      await db.exerciseSistersDao.addSister(2, 1);

      final benchSisters = await db.exerciseSistersDao.getSisters(1);
      final dumbbellSisters = await db.exerciseSistersDao.getSisters(2);
      expect(benchSisters.single.name, 'Dumbbell Press');
      expect(dumbbellSisters.single.name, 'Bench Press');
    },
  );

  test(
    'v16 migration is idempotent when exercise_sisters already exists',
    () async {
      final raw = sqlite3.openInMemory();
      raw.execute('''
      CREATE TABLE exercises (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 100),
        category TEXT NOT NULL DEFAULT 'Other',
        notes TEXT NULL,
        is_timed INTEGER NOT NULL DEFAULT 0 CHECK (is_timed IN (0, 1))
      );
    ''');
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
      raw.execute('PRAGMA user_version = 15;');

      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      await db.customSelect('SELECT 1').get();
      await db.exerciseSistersDao.addSister(1, 2);

      final sisters = await db.exerciseSistersDao.getSisters(2);
      expect(sisters.single.name, 'Squat');
    },
  );
}
