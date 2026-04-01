import 'package:drift/drift.dart';
import 'wod_templates_table.dart';
import 'exercises_table.dart';

class WodTemplateExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get wodTemplateId => integer().references(WodTemplates, #id)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get sortOrder => integer()();
  IntColumn get targetSets => integer().withDefault(const Constant(3))();
  IntColumn get repRangeMin => integer().withDefault(const Constant(6))();
  IntColumn get repRangeMax => integer().withDefault(const Constant(12))();
  TextColumn get notes => text().nullable()();
}
