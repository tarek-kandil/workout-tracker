import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:workout_tracker/database/app_database.dart';
import 'package:workout_tracker/models/weight_suggestion.dart';
import 'package:workout_tracker/models/wod_item.dart';
import 'package:workout_tracker/providers/next_workout_provider.dart';
import 'package:workout_tracker/services/personal_record_detection.dart';

const _createProgramsV21 = '''
  CREATE TABLE programs (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    notes TEXT,
    status INTEGER NOT NULL DEFAULT 0
  );
''';

const _createPhasesV21 = '''
  CREATE TABLE program_phases (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    program_id INTEGER NOT NULL REFERENCES programs(id),
    phase_number INTEGER NOT NULL,
    name TEXT NOT NULL,
    duration_weeks INTEGER NOT NULL
  );
''';

const _createWodTemplatesV21 = '''
  CREATE TABLE wod_templates (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    phase_id INTEGER NOT NULL REFERENCES program_phases(id),
    wod_number INTEGER NOT NULL,
    name TEXT NOT NULL,
    notes TEXT,
    rest_seconds INTEGER NOT NULL DEFAULT 90
  );
''';

void main() {
  test('v21 -> v22 makes phase_id nullable and preserves existing WOD rows', () async {
    final raw = sqlite3.openInMemory();
    raw.execute(_createProgramsV21);
    raw.execute(_createPhasesV21);
    raw.execute(_createWodTemplatesV21);
    raw.execute("INSERT INTO programs (id, name, status) VALUES (1, 'Hypertrophy', 0);");
    raw.execute("INSERT INTO program_phases (id, program_id, phase_number, name, duration_weeks) VALUES (10, 1, 1, 'Phase 1', 4);");
    raw.execute("INSERT INTO wod_templates (id, phase_id, wod_number, name, rest_seconds) VALUES (100, 10, 1, 'Day A', 90);");
    raw.execute('PRAGMA user_version = 21;');

    final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    // Existing program WOD preserved
    final phaseWods = await db.programsDao.getWodTemplatesForPhase(10);
    expect(phaseWods, hasLength(1));
    expect(phaseWods.first.name, 'Day A');
    expect(phaseWods.first.isArchived, isFalse);

    // Can insert a standalone Flash Workout with phaseId == null
    final flashId = await db.programsDao.insertWodTemplate(
      WodTemplatesCompanion.insert(
        phaseId: const Value(null),
        wodNumber: 0,
        name: 'Daily Mobility',
        restSeconds: const Value(45),
        reminderHour: const Value(8),
        reminderMinute: const Value(30),
      ),
    );
    final flashWorkouts = await db.programsDao.getFlashWorkouts();
    expect(flashWorkouts, hasLength(1));
    expect(flashWorkouts.first.id, flashId);
    expect(flashWorkouts.first.phaseId, isNull);
    expect(flashWorkouts.first.reminderHour, 8);
    expect(flashWorkouts.first.reminderMinute, 30);

    // Program WOD query excludes flash workouts
    final phaseWodsAfter = await db.programsDao.getWodTemplatesForPhase(10);
    expect(phaseWodsAfter, hasLength(1));
  });

  test('Timed progressive overload suggests +5s under 60s and +10s at/above 60s', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final plankId = await db.into(db.exercises).insert(
          ExercisesCompanion.insert(
            name: 'Test Plank',
            category: const Value('Core'),
            isTimed: const Value(true),
          ),
        );
    final flashId = await db.programsDao.insertWodTemplate(
      WodTemplatesCompanion.insert(
        phaseId: const Value(null),
        wodNumber: 0,
        name: 'Core Flash',
      ),
    );
    await db.programsDao.insertWodTemplateExercise(
      WodTemplateExercisesCompanion.insert(
        wodTemplateId: flashId,
        exerciseId: plankId,
        sortOrder: 0,
        targetSets: const Value(2),
        repRangeMin: const Value(30),
        repRangeMax: const Value(45),
      ),
    );

    // Log a session hitting the 45s ceiling on both sets
    final sessionId = await db.sessionsDao.insertSession(
      WorkoutSessionsCompanion.insert(
        date: DateTime(2026, 11, 10),
        workoutName: 'Core Flash',
        wodTemplateId: Value(flashId),
      ),
    );
    await db.setsDao.insertSet(WorkoutSetsCompanion.insert(
      sessionId: sessionId,
      exerciseId: plankId,
      setNumber: 1,
      reps: 0,
      weightKg: 0,
      durationSeconds: const Value(45),
    ));
    await db.setsDao.insertSet(WorkoutSetsCompanion.insert(
      sessionId: sessionId,
      exerciseId: plankId,
      setNumber: 2,
      reps: 0,
      weightKg: 0,
      durationSeconds: const Value(45),
    ));

    final exercises = await db.exercisesDao.getAllExercises();
    final map = {for (final e in exercises) e.id: e};
    final items = await buildWodItems(db, flashId, map);
    final standalone = items.single as StandaloneWodExercise;

    expect(standalone.entry.suggestion.type, SuggestionType.increase);
    expect(standalone.entry.suggestion.suggestedDurationSeconds, 50); // 45 + 5

    // Duration PR evaluation
    expect(
      evaluateDurationPersonalRecord(
        currentTopDurationSeconds: 45,
        durationSeconds: 50,
      ),
      isTrue,
    );
    expect(
      evaluateDurationPersonalRecord(
        currentTopDurationSeconds: 45,
        durationSeconds: 45,
      ),
      isFalse,
    );
  });
}
