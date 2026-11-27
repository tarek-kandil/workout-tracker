import 'package:drift/drift.dart';
import 'programs_table.dart';
import 'sync_columns_mixin.dart';

class ProgramPhases extends Table with SyncColumnsMixin {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get programId => integer().references(Programs, #id)();
  IntColumn get phaseNumber => integer()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get durationWeeks => integer()();
}
