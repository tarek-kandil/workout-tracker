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
  IntColumn get durationSeconds => integer().nullable()();
  // RPE: Rate of Perceived Exertion (6.0–10.0), optional.
  // Deprecated in favor of [rir] as of schema v18; kept for one release for
  // backward compatibility. Dual-written alongside [rir].
  RealColumn get rpe => real().nullable()();
  // RIR: Reps In Reserve (0.0–5.0), optional. RIR = 10 − RPE; lower RIR means
  // harder (0 = failure). Preferred over [rpe] as of schema v18.
  RealColumn get rir => real().nullable()();
  TextColumn get notes => text().nullable()();
}
