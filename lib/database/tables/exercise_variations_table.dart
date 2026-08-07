import 'package:drift/drift.dart';

import 'exercises_table.dart';

class ExerciseVariations extends Table {
  IntColumn get id => integer().autoIncrement()();
  @ReferenceName('exerciseVariationSources')
  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.cascade)();
  @ReferenceName('exerciseVariationAlternatives')
  IntColumn get variationExerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.cascade)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {exerciseId, variationExerciseId},
  ];
}
