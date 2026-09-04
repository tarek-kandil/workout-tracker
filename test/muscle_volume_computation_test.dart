import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/database/app_database.dart';
import 'package:workout_tracker/database/daos/muscle_volume_dao.dart';
import 'package:workout_tracker/models/exercise_muscle_seed.dart';
import 'package:workout_tracker/models/weekly_muscle_volume.dart';
import 'package:workout_tracker/providers/muscle_volume_provider.dart';
import 'package:workout_tracker/utils/constants.dart';

/// Effective-set computation tests (specs/003-muscle-volume-report):
///   credit = roleWeight(primary 1.0 / secondary 0.5)
///          * rirMultiplier(rir >= 5 -> 0.5 / missing rir -> 1.0 / else 1.0)
/// aggregated per muscle over a rolling 7-day window, then classified
/// against the muscle's landmark (Undertrained / Optimal / Overtrained).
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<int> addExercise(
    String name, {
    bool isTimed = false,
    required List<ExerciseMuscleSeed> muscles,
  }) async {
    final id = await db.exercisesDao.insertExercise(
      ExercisesCompanion.insert(name: name, isTimed: Value(isTimed)),
    );
    await db.exercisesDao.setMusclesForExercise(id, muscles);
    return id;
  }

  Future<int> addSession(DateTime date, {int? wodTemplateId}) =>
      db.sessionsDao.insertSession(WorkoutSessionsCompanion.insert(
        date: date,
        workoutName: 'Test session',
        wodTemplateId: Value(wodTemplateId),
      ));

  Future<void> addSet(
    int sessionId,
    int exerciseId,
    int setNumber, {
    int reps = 8,
    double weightKg = 60.0,
    int? durationSeconds,
    double? rir,
  }) =>
      db.setsDao.insertSet(WorkoutSetsCompanion.insert(
        sessionId: sessionId,
        exerciseId: exerciseId,
        setNumber: setNumber,
        reps: reps,
        weightKg: weightKg,
        durationSeconds: Value(durationSeconds),
        rir: Value(rir),
      ));

  double effectiveSetsFor(List<MuscleEffectiveSetRow> rows, String muscle) =>
      rows.firstWhere((r) => r.muscle == muscle,
          orElse: () => const MuscleEffectiveSetRow(
              muscle: '', effectiveSets: 0, contributingSets: 0)).effectiveSets;

  test('primary credits 1.0 and secondary credits 0.5 per completed set',
      () async {
    final now = DateTime.now();
    final benchId = await addExercise('Bench Press', muscles: [
      ExerciseMuscleSeed.primary('Chest'),
      ExerciseMuscleSeed.secondary('Triceps'),
    ]);
    final sessionId = await addSession(now.subtract(const Duration(days: 1)));
    await addSet(sessionId, benchId, 1, rir: null);

    final rows = await db.muscleVolumeDao.getRollingMuscleEffectiveSets(
        now.subtract(const Duration(days: 7)), now);

    expect(effectiveSetsFor(rows, 'Chest'), 1.0);
    expect(effectiveSetsFor(rows, 'Triceps'), 0.5);
  });

  test('rir >= 5 down-weights credit by 0.5; rir just below 5 stays full',
      () async {
    final now = DateTime.now();
    final squatId =
        await addExercise('Squat', muscles: [ExerciseMuscleSeed.primary('Quads')]);
    final sessionId = await addSession(now.subtract(const Duration(days: 1)));
    await addSet(sessionId, squatId, 1, rir: 5.0);
    await addSet(sessionId, squatId, 2, rir: 4.9);

    final rows = await db.muscleVolumeDao.getRollingMuscleEffectiveSets(
        now.subtract(const Duration(days: 7)), now);

    // set 1: 1.0 (primary) * 0.5 (rir >= 5) = 0.5
    // set 2: 1.0 (primary) * 1.0 (rir < 5)  = 1.0
    expect(effectiveSetsFor(rows, 'Quads'), 1.5);
  });

  test('missing rir counts as full credit (no down-weight)', () async {
    final now = DateTime.now();
    final rowId = await addExercise('Barbell Row',
        muscles: [ExerciseMuscleSeed.primary('Lats')]);
    final sessionId = await addSession(now.subtract(const Duration(days: 1)));
    await addSet(sessionId, rowId, 1, rir: null);

    final rows = await db.muscleVolumeDao.getRollingMuscleEffectiveSets(
        now.subtract(const Duration(days: 7)), now);

    expect(effectiveSetsFor(rows, 'Lats'), 1.0);
  });

  test('straight sets and circuit sets are counted identically', () async {
    final now = DateTime.now();
    final pushUpId = await addExercise('Push Up',
        muscles: [ExerciseMuscleSeed.primary('Chest')]);
    final benchId = await addExercise('Bench Press',
        muscles: [ExerciseMuscleSeed.primary('Chest')]);

    // Circuit scaffolding: a WOD template with a group (rounds) whose
    // member is the Push Up exercise — mirrors how ActiveSessionScreen
    // persists circuit rounds as ordinary workout_sets rows.
    final programId = await db.into(db.programs).insert(
        ProgramsCompanion.insert(name: 'Test Program'));
    final phaseId = await db.into(db.programPhases).insert(
        ProgramPhasesCompanion.insert(
            programId: programId,
            phaseNumber: 1,
            name: 'Phase 1',
            durationWeeks: 4));
    final wodTemplateId = await db.into(db.wodTemplates).insert(
        WodTemplatesCompanion.insert(
            phaseId: phaseId, wodNumber: 1, name: 'Circuit'));
    final groupId = await db.into(db.wodExerciseGroups).insert(
        WodExerciseGroupsCompanion.insert(
            wodTemplateId: wodTemplateId, sortOrder: 0));
    await db.into(db.wodTemplateExercises).insert(
        WodTemplateExercisesCompanion.insert(
          wodTemplateId: wodTemplateId,
          exerciseId: pushUpId,
          sortOrder: 0,
          groupId: Value(groupId),
        ));

    final circuitSessionId = await addSession(
        now.subtract(const Duration(days: 1)),
        wodTemplateId: wodTemplateId);
    // 3 circuit rounds of Push Up, persisted as plain workout_sets rows.
    await addSet(circuitSessionId, pushUpId, 1, rir: null);
    await addSet(circuitSessionId, pushUpId, 2, rir: null);
    await addSet(circuitSessionId, pushUpId, 3, rir: null);

    final straightSessionId =
        await addSession(now.subtract(const Duration(days: 2)));
    await addSet(straightSessionId, benchId, 1, rir: null);
    await addSet(straightSessionId, benchId, 2, rir: null);
    await addSet(straightSessionId, benchId, 3, rir: null);

    final rows = await db.muscleVolumeDao.getRollingMuscleEffectiveSets(
        now.subtract(const Duration(days: 7)), now);

    // 3 circuit-round sets + 3 straight sets, all primary/full-credit -> 6.0
    expect(effectiveSetsFor(rows, 'Chest'), 6.0);
  });

  test('rolling 7-day window excludes sets outside [from, to)', () async {
    final now = DateTime.now();
    final benchId = await addExercise('Bench Press',
        muscles: [ExerciseMuscleSeed.primary('Chest')]);

    final inWindowSession =
        await addSession(now.subtract(const Duration(days: 6)));
    await addSet(inWindowSession, benchId, 1, rir: null);

    final beforeWindowSession =
        await addSession(now.subtract(const Duration(days: 8)));
    await addSet(beforeWindowSession, benchId, 1, rir: null);

    final atOrAfterToSession = await addSession(now.add(const Duration(days: 1)));
    await addSet(atOrAfterToSession, benchId, 1, rir: null);

    final rows = await db.muscleVolumeDao.getRollingMuscleEffectiveSets(
        now.subtract(const Duration(days: 7)), now);

    expect(effectiveSetsFor(rows, 'Chest'), 1.0);
  });

  test('status classification: Undertrained below MEV, Optimal at MEV/MRV boundaries, Overtrained above MRV',
      () async {
    // Chest landmark: mev=8, mrv=22 (see kVolumeLandmarks).
    final landmark = kVolumeLandmarks['Chest']!;

    final underRow = WeeklyMuscleVolume.from(
      muscle: 'Chest',
      region: 'Chest',
      effectiveSets: landmark.mev - 0.5,
      contributingSets: 1,
      landmark: landmark,
    );
    expect(underRow.status, MuscleVolumeStatus.undertrained);

    final atMevRow = WeeklyMuscleVolume.from(
      muscle: 'Chest',
      region: 'Chest',
      effectiveSets: landmark.mev,
      contributingSets: 1,
      landmark: landmark,
    );
    expect(atMevRow.status, MuscleVolumeStatus.optimal);

    final atMrvRow = WeeklyMuscleVolume.from(
      muscle: 'Chest',
      region: 'Chest',
      effectiveSets: landmark.mrv,
      contributingSets: 1,
      landmark: landmark,
    );
    expect(atMrvRow.status, MuscleVolumeStatus.optimal);

    final overRow = WeeklyMuscleVolume.from(
      muscle: 'Chest',
      region: 'Chest',
      effectiveSets: landmark.mrv + 0.5,
      contributingSets: 1,
      landmark: landmark,
    );
    expect(overRow.status, MuscleVolumeStatus.overtrained);
  });

  test('a muscle with 0 sets this week is Undertrained', () async {
    final report = buildWeeklyMuscleVolumeReport(const []);
    final glutes = report.firstWhere((r) => r.muscle == 'Glutes');
    expect(glutes.effectiveSets, 0.0);
    expect(glutes.status, MuscleVolumeStatus.undertrained);
  });
}
