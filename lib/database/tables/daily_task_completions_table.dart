import 'package:drift/drift.dart';
import 'sync_columns_mixin.dart';

class DailyTaskCompletions extends Table with SyncColumnsMixin {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId => integer().customConstraint(
      'NOT NULL REFERENCES daily_tasks(id) ON DELETE CASCADE')();
  DateTimeColumn get completedDate => dateTime()();
}
