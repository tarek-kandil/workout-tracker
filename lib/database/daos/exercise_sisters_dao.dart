import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/exercise_sisters_table.dart';
import '../tables/exercises_table.dart';

part 'exercise_sisters_dao.g.dart';

@DriftAccessor(tables: [ExerciseSisters, Exercises])
class ExerciseSistersDao extends DatabaseAccessor<AppDatabase>
    with _$ExerciseSistersDaoMixin {
  ExerciseSistersDao(super.db);

  /// Sister links are stored once as a canonical ordered pair and exposed as
  /// symmetric relationships by DAO reads/removes.
  ({int exerciseId, int sisterExerciseId}) _canonicalPair(
    int exerciseId,
    int sisterExerciseId,
  ) {
    if (exerciseId == sisterExerciseId) {
      throw ArgumentError.value(
        sisterExerciseId,
        'sisterExerciseId',
        'An exercise cannot be its own sister',
      );
    }
    return exerciseId < sisterExerciseId
        ? (exerciseId: exerciseId, sisterExerciseId: sisterExerciseId)
        : (exerciseId: sisterExerciseId, sisterExerciseId: exerciseId);
  }

  Future<List<Exercise>> getSisters(int exerciseId) async {
    final rows =
        await (select(exerciseSisters)..where(
              (s) =>
                  s.exerciseId.equals(exerciseId) |
                  s.sisterExerciseId.equals(exerciseId),
            ))
            .get();
    final sisterIds = rows
        .map(
          (s) => s.exerciseId == exerciseId ? s.sisterExerciseId : s.exerciseId,
        )
        .toSet()
        .toList();
    if (sisterIds.isEmpty) return [];
    return (select(exercises)
          ..where((e) => e.id.isIn(sisterIds))
          ..orderBy([(e) => OrderingTerm(expression: e.name)]))
        .get();
  }

  Future<int> addSister(int exerciseId, int sisterExerciseId) {
    final pair = _canonicalPair(exerciseId, sisterExerciseId);
    return into(exerciseSisters).insert(
      ExerciseSistersCompanion.insert(
        exerciseId: pair.exerciseId,
        sisterExerciseId: pair.sisterExerciseId,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> removeSister(int exerciseId, int sisterExerciseId) {
    final pair = _canonicalPair(exerciseId, sisterExerciseId);
    return (delete(exerciseSisters)..where(
          (s) =>
              s.exerciseId.equals(pair.exerciseId) &
              s.sisterExerciseId.equals(pair.sisterExerciseId),
        ))
        .go();
  }
}
