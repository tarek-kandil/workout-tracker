import 'package:drift/drift.dart';

import 'exercises_table.dart';

class ExerciseSisters extends Table {
  IntColumn get id => integer().autoIncrement()();
  @ReferenceName('exerciseSisterSources')
  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.cascade)();
  @ReferenceName('exerciseSisterAlternatives')
  IntColumn get sisterExerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.cascade)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {exerciseId, sisterExerciseId},
  ];
}
