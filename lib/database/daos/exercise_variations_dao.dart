import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/exercise_variations_table.dart';
import '../tables/exercises_table.dart';

part 'exercise_variations_dao.g.dart';

@DriftAccessor(tables: [ExerciseVariations, Exercises])
class ExerciseVariationsDao extends DatabaseAccessor<AppDatabase>
    with _$ExerciseVariationsDaoMixin {
  ExerciseVariationsDao(super.db);

  /// Variation links are stored once as a canonical ordered pair and exposed as
  /// symmetric relationships by DAO reads/removes.
  ({int exerciseId, int variationExerciseId}) _canonicalPair(
    int exerciseId,
    int variationExerciseId,
  ) {
    if (exerciseId == variationExerciseId) {
      throw ArgumentError.value(
        variationExerciseId,
        'variationExerciseId',
        'An exercise cannot be a variation of itself',
      );
    }
    return exerciseId < variationExerciseId
        ? (exerciseId: exerciseId, variationExerciseId: variationExerciseId)
        : (exerciseId: variationExerciseId, variationExerciseId: exerciseId);
  }

  Future<List<Exercise>> getVariations(int exerciseId) async {
    final rows =
        await (select(exerciseVariations)..where(
              (s) =>
                  s.exerciseId.equals(exerciseId) |
                  s.variationExerciseId.equals(exerciseId),
            ))
            .get();
    final variationIds = rows
        .map(
          (s) =>
              s.exerciseId == exerciseId ? s.variationExerciseId : s.exerciseId,
        )
        .toSet()
        .toList();
    if (variationIds.isEmpty) return [];
    return (select(exercises)
          ..where((e) => e.id.isIn(variationIds))
          ..orderBy([(e) => OrderingTerm(expression: e.name)]))
        .get();
  }

  Future<int> addVariation(int exerciseId, int variationExerciseId) {
    final pair = _canonicalPair(exerciseId, variationExerciseId);
    return into(exerciseVariations).insert(
      ExerciseVariationsCompanion.insert(
        exerciseId: pair.exerciseId,
        variationExerciseId: pair.variationExerciseId,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> removeVariation(int exerciseId, int variationExerciseId) {
    final pair = _canonicalPair(exerciseId, variationExerciseId);
    return (delete(exerciseVariations)..where(
          (s) =>
              s.exerciseId.equals(pair.exerciseId) &
              s.variationExerciseId.equals(pair.variationExerciseId),
        ))
        .go();
  }
}
