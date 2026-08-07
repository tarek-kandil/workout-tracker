import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:workout_tracker/database/app_database.dart';

void main() {
  test('v14 -> v15 creates exercise_notes and persists note history', () async {
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
      "INSERT INTO exercises (id, name, category, notes, is_timed) "
      "VALUES (1, 'Bench Press', 'Strength', NULL, 0);",
    );
    raw.execute('PRAGMA user_version = 14;');

    final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();

    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'exercise_notes'",
        )
        .get();
    expect(tables, hasLength(1));

    await db.exerciseNotesDao.addNote(1, 'Keep elbows tucked');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await db.exerciseNotesDao.addNote(1, 'Add a pause rep next time');

    final notes = await db.exerciseNotesDao.getNotesForExercise(1);
    expect(notes.map((n) => n.note), [
      'Add a pause rep next time',
      'Keep elbows tucked',
    ]);
  });

  test(
    'v15 migration is idempotent when exercise_notes already exists',
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
      CREATE TABLE exercise_notes (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        exercise_id INTEGER NOT NULL REFERENCES exercises(id),
        note TEXT NOT NULL CHECK (length(note) >= 1),
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP))
      );
    ''');
      raw.execute(
        "INSERT INTO exercises (id, name, category, notes, is_timed) "
        "VALUES (1, 'Squat', 'Strength', NULL, 0);",
      );
      raw.execute('PRAGMA user_version = 14;');

      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      await db.customSelect('SELECT 1').get();
      await db.exerciseNotesDao.addNote(1, 'Brace before unracking');

      final notes = await db.exerciseNotesDao.getNotesForExercise(1);
      expect(notes.single.note, 'Brace before unracking');
    },
  );
}
