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
}
