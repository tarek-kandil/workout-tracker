import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import 'database_provider.dart';

final exercisesProvider = StreamProvider<List<Exercise>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.exercisesDao.watchAllExercises();
});

/// Reactive map: exerciseId → active [ExerciseMuscle] rows (primary first).
/// Empty list means no muscle assigned for that exercise.
final exerciseMuscleMapProvider =
    StreamProvider<Map<int, List<ExerciseMuscle>>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.exercisesDao.watchAllMuscleAssignmentMap();
});

/// Exercises still flagged as needing a muscle-assignment review
/// (FR-016/FR-017) — either the v20 migration guessed ambiguously or the
/// athlete has not assigned muscles yet.
final exercisesNeedingMuscleReviewProvider =
    FutureProvider<List<Exercise>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.exercisesDao.getExercisesNeedingMuscleReview();
});

final variationsForExerciseProvider = FutureProvider.family<List<Exercise>, int>((
  ref,
  exerciseId,
) {
  final db = ref.watch(databaseProvider);
  return db.exerciseVariationsDao.getVariations(exerciseId);
});

