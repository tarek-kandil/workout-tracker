import 'package:drift/drift.dart';
import 'program_phases_table.dart';

class WodTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// Null for a standalone "flash workout" (not part of any program phase).
  IntColumn get phaseId => integer().nullable().references(ProgramPhases, #id)();
  IntColumn get wodNumber => integer()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get notes => text().nullable()();
  IntColumn get restSeconds => integer().withDefault(const Constant(90))();

  // ── Flash workout fields (only meaningful when phaseId is null) ────────────
  /// Weekday reminder bitmask: bit 0 = Monday … bit 6 = Sunday. Null = none.
  IntColumn get reminderDays => integer().nullable()();
  IntColumn get reminderHour => integer().nullable()();
  IntColumn get reminderMinute => integer().nullable()();
  /// Soft-delete: hides a flash workout that already has logged history.
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
