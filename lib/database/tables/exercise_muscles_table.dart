import 'package:drift/drift.dart';
import 'exercises_table.dart';

class ExerciseMuscles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.cascade)();
  TextColumn get muscle => text()();
  IntColumn get sortOrder => integer()();
  // Schema v20 (Muscle Taxonomy + Weekly Volume Report): explicit
  // primary/secondary role, replacing the old sortOrder==0 convention.
  // Role weights (primary=1.0, secondary=0.5) are code constants — see
  // kMuscleRoleWeights in utils/constants.dart.
  TextColumn get role =>
      text().withDefault(const Constant('primary'))();
  // Schema v20: preserves legacy/superseded exercise_muscles rows without
  // deleting them (non-destructive migration) while excluding them from
  // muscle-volume reports and reads.
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();
}
