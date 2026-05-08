import 'package:drift/drift.dart';
import 'wod_templates_table.dart';
import 'wod_exercise_groups_table.dart';
import 'exercises_table.dart';

class WodTemplateExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get wodTemplateId => integer().references(WodTemplates, #id)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  // For standalone exercises: position in the WOD.
  // For circuit exercises: position within the circuit.
  IntColumn get sortOrder => integer()();
  // Null = belongs to no circuit (standalone)
  IntColumn get groupId =>
      integer().nullable().references(WodExerciseGroups, #id)();
  IntColumn get targetSets => integer().withDefault(const Constant(3))();
  IntColumn get repRangeMin => integer().withDefault(const Constant(6))();
  IntColumn get repRangeMax => integer().withDefault(const Constant(12))();
  TextColumn get notes => text().nullable()();
  // Per-exercise rest override (null = use WOD default). Standalone only.
  IntColumn get restSeconds => integer().nullable()();
}
