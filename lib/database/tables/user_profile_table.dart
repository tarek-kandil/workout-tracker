import 'package:drift/drift.dart';

class UserProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withDefault(const Constant(''))();
  // male | female | other
  TextColumn get gender => text().withDefault(const Constant('male'))();
  IntColumn get age => integer().nullable()();
  RealColumn get heightCm => real().nullable()();
  RealColumn get weightKg => real().nullable()();
  RealColumn get targetWeightKg => real().nullable()();
  // lose | build | maintain | fitness
  TextColumn get fitnessGoal => text().withDefault(const Constant('maintain'))();
  // sedentary | light | moderate | active | athletic
  TextColumn get activityLevel => text().withDefault(const Constant('moderate'))();
  // kg/week pace (0.25, 0.5, 0.75, 1.0 for lose; 0.1, 0.25, 0.5, 0.75 for build)
  RealColumn get weeklyRateKg => real().nullable()();

  // ── Weight Goal Coaching Loop (schema v19) ──────────────────────────────
  // All nullable/additive: no active plan means these stay null.
  DateTimeColumn get planStartDate => dateTime().nullable()();
  RealColumn get planStartWeightKg => real().nullable()();
  DateTimeColumn get planTargetDate => dateTime().nullable()();
  // Days between planned weigh-ins (3, 7, 14, or custom).
  IntColumn get weighInIntervalDays => integer().nullable()();
  BoolColumn get weighInRemindersEnabled =>
      boolean().nullable().withDefault(const Constant(true))();
  DateTimeColumn get weighInLastReminderAt => dateTime().nullable()();
}
