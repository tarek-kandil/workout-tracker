import 'package:drift/drift.dart';
import 'wod_templates_table.dart';

class WorkoutSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  // Human-readable name — auto-filled from WOD template, or user-entered for ad-hoc sessions
  TextColumn get workoutName => text()();
  // Null for ad-hoc sessions; set when started from a program WOD
  IntColumn get wodTemplateId =>
      integer().nullable().references(WodTemplates, #id)();
  // Calendar week number within the program (1-based). Null for ad-hoc sessions.
  IntColumn get weekNumber => integer().nullable()();
  TextColumn get notes => text().nullable()();
}
