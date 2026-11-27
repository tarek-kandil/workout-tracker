import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:workout_tracker/database/app_database.dart';
import 'package:workout_tracker/utils/constants.dart';

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  group('Schema v28 — Global & Per-User Sync UUIDs', () {
    test('two independent installs produce identical deterministic UUID v5s for the global catalog, muscles, and variations', () async {
      final dbA = AppDatabase.forTesting(NativeDatabase.memory());
      final dbB = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() async {
        await dbA.close();
        await dbB.close();
      });

      await dbA.exercisesDao.syncGlobalCatalogV1();
      await dbB.exercisesDao.syncGlobalCatalogV1();

      final exA = {
        for (final e in await dbA.exercisesDao.getAllExercises())
          e.canonicalKey!: e.syncId,
      };
      final exB = {
        for (final e in await dbB.exercisesDao.getAllExercises())
          e.canonicalKey!: e.syncId,
      };

      expect(exA.length, kGlobalExerciseCatalog.length);
      expect(exA, equals(exB));
      for (final uuid in exA.values) {
        expect(_uuidPattern.hasMatch(uuid), isTrue, reason: 'Invalid UUID: $uuid');
      }

      // Active muscle syncIds match identically across devices.
      final musclesA = (await (dbA.select(dbA.exerciseMuscles)
                ..where((m) => m.isActive.equals(true)))
              .get())
          .map((m) => m.syncId)
          .toSet();
      final musclesB = (await (dbB.select(dbB.exerciseMuscles)
                ..where((m) => m.isActive.equals(true)))
              .get())
          .map((m) => m.syncId)
          .toSet();
      expect(musclesA, isNotEmpty);
      expect(musclesA, equals(musclesB));

      // Seeded variation syncIds match identically across devices.
      final varsA = (await dbA.select(dbA.exerciseVariations).get())
          .map((v) => v.syncId)
          .toSet();
      final varsB = (await dbB.select(dbB.exerciseVariations).get())
          .map((v) => v.syncId)
          .toSet();
      expect(varsA, isNotEmpty);
      expect(varsA, equals(varsB));
    });

    test('partial DAO updates preserve syncId and canonicalKey without resetting them', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await db.exercisesDao.syncGlobalCatalogV1();
      final bench = (await db.exercisesDao.getAllExercises())
          .firstWhere((e) => e.name == 'Bench Press');
      final originalSyncId = bench.syncId;

      await db.exercisesDao.updateExercise(
        ExercisesCompanion(
          id: Value(bench.id),
          notes: const Value('Pause 1s on chest'),
        ),
      );

      final updatedBench = (await db.exercisesDao.getAllExercises())
          .firstWhere((e) => e.id == bench.id);
      expect(updatedBench.syncId, originalSyncId);
      expect(updatedBench.canonicalKey, 'bench_press');
      expect(updatedBench.notes, 'Pause 1s on chest');

      final progId = await db.programsDao.insertProgram(
        ProgramsCompanion.insert(name: 'Strength Block'),
      );
      final progBefore =
          (await db.programsDao.getAllPrograms()).singleWhere((p) => p.id == progId);
      expect(_uuidPattern.hasMatch(progBefore.syncId), isTrue);

      await db.programsDao.updateProgram(
        ProgramsCompanion(id: Value(progId), name: const Value('Peak Block')),
      );
      final progAfter =
          (await db.programsDao.getAllPrograms()).singleWhere((p) => p.id == progId);
      expect(progAfter.syncId, progBefore.syncId);
      expect(progAfter.name, 'Peak Block');
    });

    test('v27 -> v28 migration backfills UUIDs across existing rows, enforces unique indexes, and mirrors personal exercise state', () async {
      final raw = sqlite3.openInMemory();
      raw.execute('''
        CREATE TABLE exercises (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          category TEXT NOT NULL DEFAULT 'Other',
          notes TEXT NULL,
          is_timed INTEGER NOT NULL DEFAULT 0,
          tracking_mode TEXT NOT NULL DEFAULT 'weighted_reps',
          muscle_needs_review INTEGER NOT NULL DEFAULT 0,
          muscle_review_note TEXT NULL,
          archived INTEGER NOT NULL DEFAULT 0,
          canonical_key TEXT NULL
        );
        CREATE TABLE programs (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          status INTEGER NOT NULL DEFAULT 2,
          notes TEXT NULL
        );
        CREATE TABLE workout_sessions (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          date INTEGER NOT NULL,
          workout_name TEXT NOT NULL,
          wod_template_id INTEGER NULL,
          week_number INTEGER NULL,
          notes TEXT NULL
        );
        CREATE TABLE workout_sets (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          session_id INTEGER NOT NULL REFERENCES workout_sessions(id),
          exercise_id INTEGER NOT NULL REFERENCES exercises(id),
          set_number INTEGER NOT NULL,
          reps INTEGER NOT NULL,
          weight_kg REAL NOT NULL,
          duration_seconds INTEGER NULL,
          rpe REAL NULL,
          rir REAL NULL,
          notes TEXT NULL
        );
      ''');

      raw.execute(
        "INSERT INTO exercises (id, name, canonical_key) VALUES (1, 'Bench Press', 'bench_press');",
      );
      raw.execute(
        "INSERT INTO exercises (id, name, archived, notes) VALUES (2, 'Old Custom Press', 1, 'Archived shoulder saver');",
      );
      raw.execute("INSERT INTO programs (id, name, status) VALUES (1, 'Upper Lower', 0);");
      raw.execute("INSERT INTO workout_sessions (id, date, workout_name) VALUES (1, 1700000000, 'Upper A');");
      raw.execute("INSERT INTO workout_sets (id, session_id, exercise_id, set_number, reps, weight_kg) VALUES (1, 1, 1, 1, 8, 100.0);");
      raw.execute('PRAGMA user_version = 27;');

      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      final allEx = await db.exercisesDao.getAllExercisesIncludingArchived();
      final byId = {for (final e in allEx) e.id: e};

      // Global exercise got deterministic UUID v5; custom exercise got random UUID v4.
      expect(byId[1]!.syncId, globalExerciseSyncId('bench_press'));
      expect(_uuidPattern.hasMatch(byId[2]!.syncId), isTrue);
      expect(byId[2]!.syncId, isNot(equals(byId[1]!.syncId)));

      // Program, session, and set all got backfilled UUID v4s.
      final prog = (await db.programsDao.getAllPrograms()).single;
      final session = (await db.sessionsDao.getAllSessions()).single;
      final sets = await db.setsDao.getSetsForSession(session.id);
      expect(_uuidPattern.hasMatch(prog.syncId), isTrue);
      expect(_uuidPattern.hasMatch(session.syncId), isTrue);
      expect(_uuidPattern.hasMatch(sets.single.syncId), isTrue);
      expect(sets.single.weightKg, 100.0);

      // Personal exercise state (archived + notes) mirrored into user_exercise_settings.
      final settings = await db.select(db.userExerciseSettings).get();
      expect(settings, hasLength(1));
      expect(settings.single.exerciseId, 2);
      expect(settings.single.archived, isTrue);
      expect(settings.single.notes, 'Archived shoulder saver');
      expect(_uuidPattern.hasMatch(settings.single.syncId), isTrue);
    });
  });
}
