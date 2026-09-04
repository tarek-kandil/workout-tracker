import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/database/app_database.dart';
import 'package:workout_tracker/database/daos/exercises_dao.dart';

/// Non-destructive exercise deletion (deleteOrArchiveExercise):
///  - no logged history -> hard delete (row + exercise_muscles gone)
///  - logged history (>=1 workout_sets row) -> archive instead, keeping the
///    exercise row and every workout_sets row that references it
///  - either outcome removes the exercise from any wod_template_exercises
///    row it belonged to, so it leaves active program templates
///  - archived exercises are hidden from watchAllExercises/getAllExercises
///    (library/pickers) but remain visible to getExerciseIdsByName (seeding)
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<int> addExercise(String name) => db.exercisesDao.insertExercise(
        ExercisesCompanion.insert(name: name),
      );

  Future<int> addSession() => db.sessionsDao.insertSession(
        WorkoutSessionsCompanion.insert(
          date: DateTime(2026, 1, 1),
          workoutName: 'Test session',
        ),
      );

  test('exercise with no logged history is hard-deleted', () async {
    final exerciseId = await addExercise('Never Logged');
    await db.exercisesDao.setMusclesForExercise(exerciseId, []);
    await db.exercisesDao.clearMuscleReview(exerciseId); // no-op sanity call

    final outcome = await db.exercisesDao.deleteOrArchiveExercise(exerciseId);
    expect(outcome, ExerciseDeleteOutcome.hardDeleted);

    final remaining = await db.exercisesDao.getAllExercisesIncludingArchived();
    expect(remaining.where((e) => e.id == exerciseId), isEmpty);

    final musclesLeft = await (db.select(db.exerciseMuscles)
          ..where((m) => m.exerciseId.equals(exerciseId)))
        .get();
    expect(musclesLeft, isEmpty);
  });

  test('exercise with logged history is archived, not deleted', () async {
    final exerciseId = await addExercise('Heavily Logged');
    final sessionId = await addSession();
    await db.setsDao.insertSet(WorkoutSetsCompanion.insert(
      sessionId: sessionId,
      exerciseId: exerciseId,
      setNumber: 1,
      reps: 8,
      weightKg: 60.0,
    ));

    final outcome = await db.exercisesDao.deleteOrArchiveExercise(exerciseId);
    expect(outcome, ExerciseDeleteOutcome.archived);

    // Exercise row still present, now archived.
    final all = await db.exercisesDao.getAllExercisesIncludingArchived();
    final archivedExercise = all.firstWhere((e) => e.id == exerciseId);
    expect(archivedExercise.archived, isTrue);

    // The logged set is untouched.
    final sets = await db.setsDao.getSetsForSession(sessionId);
    expect(sets, hasLength(1));
    expect(sets.single.exerciseId, exerciseId);

    // Hidden from the library-facing queries...
    final libraryList = await db.exercisesDao.getAllExercises();
    expect(libraryList.where((e) => e.id == exerciseId), isEmpty);
    final watched = await db.exercisesDao.watchAllExercises().first;
    expect(watched.where((e) => e.id == exerciseId), isEmpty);

    // ...but still resolvable by name for seeding/name-matching.
    final idsByName = await db.exercisesDao.getExerciseIdsByName();
    expect(idsByName['Heavily Logged'], exerciseId);
  });

  test(
      'both outcomes remove the exercise from wod_template_exercises rows',
      () async {
    final programId =
        await db.programsDao.insertProgram(const ProgramsCompanion(
      name: Value('Test Program'),
    ));
    final phaseId = await db.programsDao.insertPhase(ProgramPhasesCompanion(
      programId: Value(programId),
      phaseNumber: const Value(1),
      name: const Value('Phase 1'),
      durationWeeks: const Value(4),
    ));
    final wodId = await db.programsDao.insertWodTemplate(WodTemplatesCompanion(
      phaseId: Value(phaseId),
      wodNumber: const Value(1),
      name: const Value('WOD 1'),
    ));

    // No-history exercise (will hard-delete).
    final noHistoryId = await addExercise('Template Only');
    await db.programsDao.insertWodTemplateExercise(
      WodTemplateExercisesCompanion(
        wodTemplateId: Value(wodId),
        exerciseId: Value(noHistoryId),
        sortOrder: const Value(1),
      ),
    );

    // Logged exercise (will archive).
    final loggedId = await addExercise('Template + Logged');
    final sessionId = await addSession();
    await db.setsDao.insertSet(WorkoutSetsCompanion.insert(
      sessionId: sessionId,
      exerciseId: loggedId,
      setNumber: 1,
      reps: 5,
      weightKg: 40.0,
    ));
    await db.programsDao.insertWodTemplateExercise(
      WodTemplateExercisesCompanion(
        wodTemplateId: Value(wodId),
        exerciseId: Value(loggedId),
        sortOrder: const Value(2),
      ),
    );

    final outcome1 =
        await db.exercisesDao.deleteOrArchiveExercise(noHistoryId);
    final outcome2 = await db.exercisesDao.deleteOrArchiveExercise(loggedId);
    expect(outcome1, ExerciseDeleteOutcome.hardDeleted);
    expect(outcome2, ExerciseDeleteOutcome.archived);

    final remainingTemplateRefs =
        await db.programsDao.getWodTemplatesForPhase(phaseId);
    expect(remainingTemplateRefs, hasLength(1)); // the WOD template itself

    final templateExerciseRows = await (db.select(db.wodTemplateExercises)
          ..where((te) => te.wodTemplateId.equals(wodId)))
        .get();
    expect(templateExerciseRows, isEmpty);
  });
}
