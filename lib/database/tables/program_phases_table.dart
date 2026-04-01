import 'package:drift/drift.dart';
import 'programs_table.dart';

class ProgramPhases extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get programId => integer().references(Programs, #id)();
  IntColumn get phaseNumber => integer()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get durationWeeks => integer()();
}
