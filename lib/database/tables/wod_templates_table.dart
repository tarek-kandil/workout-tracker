import 'package:drift/drift.dart';
import 'program_phases_table.dart';

class WodTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get phaseId => integer().references(ProgramPhases, #id)();
  IntColumn get wodNumber => integer()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get notes => text().nullable()();
  IntColumn get restSeconds => integer().withDefault(const Constant(90))();
}
