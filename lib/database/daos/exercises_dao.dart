import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/exercises_table.dart';
import '../tables/exercise_muscles_table.dart';

part 'exercises_dao.g.dart';

@DriftAccessor(tables: [Exercises, ExerciseMuscles])
class ExercisesDao extends DatabaseAccessor<AppDatabase>
    with _$ExercisesDaoMixin {
  ExercisesDao(super.db);

  // ── Exercises ──────────────────────────────────────────────────────────────

  Stream<List<Exercise>> watchAllExercises() =>
      (select(exercises)
        ..orderBy([(e) => OrderingTerm(expression: e.name)]))
      .watch();

  Future<List<Exercise>> getAllExercises() =>
      (select(exercises)
        ..orderBy([(e) => OrderingTerm(expression: e.name)]))
      .get();

  Future<Map<String, int>> getExerciseIdsByName() async {
    final all = await getAllExercises();
    return {for (final e in all) e.name: e.id};
  }

  Future<int> insertExercise(ExercisesCompanion entry) =>
      into(exercises).insert(entry);

  Future<bool> updateExercise(ExercisesCompanion entry) =>
      update(exercises).replace(entry);

  Future<int> deleteExercise(int id) =>
      (delete(exercises)..where((e) => e.id.equals(id))).go();

  Future<void> seedExercises(List<ExercisesCompanion> entries) async {
    await batch((b) => b.insertAllOnConflictUpdate(exercises, entries));
  }

  // ── Muscles ────────────────────────────────────────────────────────────────

  /// Returns ordered muscles for one exercise (sort_order ASC).
  Future<List<ExerciseMuscle>> getMusclesForExercise(int exerciseId) =>
      (select(exerciseMuscles)
        ..where((m) => m.exerciseId.equals(exerciseId))
        ..orderBy([(m) => OrderingTerm(expression: m.sortOrder)]))
      .get();

  /// Replaces all muscle rows for an exercise.
  Future<void> setMusclesForExercise(int exerciseId, List<String> muscles) async {
    await (delete(exerciseMuscles)
          ..where((m) => m.exerciseId.equals(exerciseId)))
        .go();
    for (int i = 0; i < muscles.length; i++) {
      await into(exerciseMuscles).insert(ExerciseMusclesCompanion(
        exerciseId: Value(exerciseId),
        muscle: Value(muscles[i]),
        sortOrder: Value(i),
      ));
    }
  }

  /// Reactive map: exerciseId → [primary, secondary, …] (sort_order ASC).
  Stream<Map<int, List<String>>> watchAllMuscleMap() =>
      (select(exerciseMuscles)
        ..orderBy([(m) => OrderingTerm(expression: m.sortOrder)]))
      .watch()
      .map((rows) {
        final map = <int, List<String>>{};
        for (final r in rows) {
          (map[r.exerciseId] ??= []).add(r.muscle);
        }
        return map;
      });
}
