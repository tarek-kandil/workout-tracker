import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/database/app_database.dart';
import 'package:workout_tracker/models/exercise_muscle_seed.dart';
import 'package:workout_tracker/models/weekly_muscle_volume.dart';
import 'package:workout_tracker/providers/database_provider.dart';
import 'package:workout_tracker/providers/exercise_providers.dart';
import 'package:workout_tracker/providers/muscle_volume_provider.dart';
import 'package:workout_tracker/utils/constants.dart';

/// Weekly Muscle Volume report provider tests (FR-007/FR-014): the report
/// always contains exactly the 21 taxonomy muscles, region-grouped, even
/// for a brand-new/empty database, and the unmapped-exercise count reacts
/// to review flags and missing primary assignments.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  test('report contains exactly the 21 taxonomy muscles for an empty database',
      () async {
    final report = await container.read(weeklyMuscleVolumeProvider.future);

    expect(report, hasLength(21));
    expect(report.map((r) => r.muscle).toSet(), kTrainableMuscles.toSet());
    expect(report.every((r) => r.effectiveSets == 0.0), isTrue);
    expect(
      report.every((r) => r.status == MuscleVolumeStatus.undertrained),
      isTrue,
    );
  });

  test('report preserves the fixed region-grouped display order', () async {
    final report = await container.read(weeklyMuscleVolumeProvider.future);
    expect(report.map((r) => r.muscle).toList(), kTrainableMuscles);
  });

  test('unmappedExerciseCountProvider counts exercises with no primary assignment',
      () async {
    // No muscles assigned at all -> unmapped.
    await db.exercisesDao.insertExercise(
      ExercisesCompanion.insert(name: 'Mystery Machine'),
    );
    // Only a secondary assigned, no primary -> still unmapped.
    final onlySecondaryId = await db.exercisesDao.insertExercise(
      ExercisesCompanion.insert(name: 'Half Assigned'),
    );
    await db.exercisesDao.setMusclesForExercise(
        onlySecondaryId, [ExerciseMuscleSeed.secondary('Triceps')]);
    // Fully assigned -> not unmapped.
    final mappedId = await db.exercisesDao.insertExercise(
      ExercisesCompanion.insert(name: 'Bench Press'),
    );
    await db.exercisesDao
        .setMusclesForExercise(mappedId, [ExerciseMuscleSeed.primary('Chest')]);
    // Default cardio exercise with no assignment -> intentionally excluded.
    await db.exercisesDao.insertExercise(
      ExercisesCompanion.insert(name: 'Treadmill Run'),
    );

    final count = await container.read(unmappedExerciseCountProvider.future);
    expect(count, 2);
  });

  test('unmappedExerciseCountProvider counts exercises flagged needs-review',
      () async {
    final id = await db.exercisesDao.insertExercise(
      ExercisesCompanion.insert(name: 'Needs Review Exercise'),
    );
    await db.exercisesDao.setMusclesForExercise(
        id, [ExerciseMuscleSeed.primary('Lats')]);
    await (db.update(db.exercises)..where((e) => e.id.equals(id))).write(
      const ExercisesCompanion(muscleNeedsReview: Value(true)),
    );

    final count = await container.read(unmappedExerciseCountProvider.future);
    expect(count, 1);
  });

  test('exercisesNeedingMuscleReviewProvider surfaces flagged exercises',
      () async {
    final id = await db.exercisesDao.insertExercise(
      ExercisesCompanion.insert(name: 'Ambiguous Row'),
    );
    await (db.update(db.exercises)..where((e) => e.id.equals(id))).write(
      const ExercisesCompanion(muscleNeedsReview: Value(true)),
    );

    final flagged =
        await container.read(exercisesNeedingMuscleReviewProvider.future);
    expect(flagged.map((e) => e.id), contains(id));
  });
}
