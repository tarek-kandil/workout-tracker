import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/exercises_table.dart';

part 'exercises_dao.g.dart';

@DriftAccessor(tables: [Exercises])
class ExercisesDao extends DatabaseAccessor<AppDatabase>
    with _$ExercisesDaoMixin {
  ExercisesDao(super.db);

  // Watch all exercises, sorted by category then name — reactive stream
  Stream<List<Exercise>> watchAllExercises() =>
      (select(exercises)..orderBy([(e) => OrderingTerm(expression: e.category), (e) => OrderingTerm(expression: e.name)])).watch();

  Future<List<Exercise>> getAllExercises() =>
      (select(exercises)..orderBy([(e) => OrderingTerm(expression: e.name)])).get();

  Future<int> insertExercise(ExercisesCompanion entry) =>
      into(exercises).insert(entry);

  Future<bool> updateExercise(ExercisesCompanion entry) =>
      update(exercises).replace(entry);

  Future<int> deleteExercise(int id) =>
      (delete(exercises)..where((e) => e.id.equals(id))).go();

  // Bulk insert — used for seeding the default exercise library on first launch
  Future<void> seedExercises(List<ExercisesCompanion> entries) async {
    await batch((b) => b.insertAllOnConflictUpdate(exercises, entries));
  }
}
