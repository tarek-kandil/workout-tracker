import 'package:drift/drift.dart';
import 'sessions_table.dart';
import 'exercises_table.dart';

// Named WorkoutSets to avoid conflict with Dart's built-in Set type
class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(WorkoutSessions, #id)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get setNumber => integer()();
  IntColumn get reps => integer()();
  RealColumn get weightKg => real()();
  // RPE: Rate of Perceived Exertion (6.0–10.0), optional
  RealColumn get rpe => real().nullable()();
  TextColumn get notes => text().nullable()();
}
