import 'package:drift/drift.dart';
import 'exercises_table.dart';

class Challenges extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.cascade)();
  RealColumn get targetWeightKg => real().nullable()();
  IntColumn get targetReps => integer().nullable()();
  IntColumn get targetDurationSeconds => integer().nullable()();
  BoolColumn get isCompleted =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class ChallengeAttempts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get challengeId =>
      integer().references(Challenges, #id, onDelete: KeyAction.cascade)();
  RealColumn get weightKg => real().withDefault(const Constant(0.0))();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  IntColumn get durationSeconds => integer().nullable()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
}

class ChallengeMilestones extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get challengeId =>
      integer().references(Challenges, #id, onDelete: KeyAction.cascade)();
  RealColumn get targetWeightKg => real().nullable()();
  IntColumn get targetReps => integer().nullable()();
  IntColumn get targetDurationSeconds => integer().nullable()();
  DateTimeColumn get achievedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
