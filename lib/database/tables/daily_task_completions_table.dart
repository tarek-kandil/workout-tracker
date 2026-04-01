import 'package:drift/drift.dart';

class DailyTaskCompletions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId => integer().customConstraint(
      'NOT NULL REFERENCES daily_tasks(id) ON DELETE CASCADE')();
  DateTimeColumn get completedDate => dateTime()();
}
