import 'package:drift/drift.dart';

class DailyTasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get iconName => text().nullable()();
  IntColumn get reminderHour => integer().nullable()();
  IntColumn get reminderMinute => integer().nullable()();
  /// Weekday reminder bitmask: bit 0 = Mon … bit 6 = Sun. Null or 127 = every day.
  IntColumn get reminderDays => integer().nullable()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
