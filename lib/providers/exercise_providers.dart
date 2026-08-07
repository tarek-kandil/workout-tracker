import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import 'database_provider.dart';

final exercisesProvider = StreamProvider<List<Exercise>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.exercisesDao.watchAllExercises();
});

/// Reactive map: exerciseId → [primary muscle, ...secondary muscles].
/// Empty list means no muscles assigned for that exercise.
final exerciseMuscleMapProvider = StreamProvider<Map<int, List<String>>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.exercisesDao.watchAllMuscleMap();
});

final variationsForExerciseProvider = FutureProvider.family<List<Exercise>, int>((
  ref,
  exerciseId,
) {
  final db = ref.watch(databaseProvider);
  return db.exerciseVariationsDao.getVariations(exerciseId);
});
