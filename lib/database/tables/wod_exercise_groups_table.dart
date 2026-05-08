import 'package:drift/drift.dart';
import 'wod_templates_table.dart';

class WodExerciseGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get wodTemplateId => integer().references(WodTemplates, #id)();
  IntColumn get sortOrder => integer()();
  TextColumn get name => text().nullable()();
  IntColumn get rounds => integer().withDefault(const Constant(3))();
  IntColumn get restBetweenExercisesSeconds =>
      integer().withDefault(const Constant(0))();
  IntColumn get restBetweenRoundsSeconds =>
      integer().withDefault(const Constant(90))();
}
