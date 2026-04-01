import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/daily_tasks_table.dart';
import '../tables/daily_task_completions_table.dart';

part 'daily_tasks_dao.g.dart';

@DriftAccessor(tables: [DailyTasks, DailyTaskCompletions])
class DailyTasksDao extends DatabaseAccessor<AppDatabase>
    with _$DailyTasksDaoMixin {
  DailyTasksDao(super.db);

  Stream<List<DailyTask>> watchAllTasks() => (select(dailyTasks)
        ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
      .watch();

  Stream<List<DailyTaskCompletion>> watchTodayCompletions() {
    final today = _todayStart();
    final tomorrow = today.add(const Duration(days: 1));
    return (select(dailyTaskCompletions)
          ..where((c) =>
              c.completedDate.isBiggerOrEqualValue(today) &
              c.completedDate.isSmallerThanValue(tomorrow)))
        .watch();
  }

  Future<int> insertTask(DailyTasksCompanion entry) =>
      into(dailyTasks).insert(entry);

  Future<void> updateTask(DailyTasksCompanion entry) =>
      (update(dailyTasks)..where((t) => t.id.equals(entry.id.value)))
          .write(entry);

  Future<void> deleteTask(int id) =>
      (delete(dailyTasks)..where((t) => t.id.equals(id))).go();

  Future<void> setCompletion(int taskId, bool completed) async {
    final today = _todayStart();
    final tomorrow = today.add(const Duration(days: 1));
    if (completed) {
      final existing = await (select(dailyTaskCompletions)
            ..where((c) =>
                c.taskId.equals(taskId) &
                c.completedDate.isBiggerOrEqualValue(today) &
                c.completedDate.isSmallerThanValue(tomorrow)))
          .getSingleOrNull();
      if (existing == null) {
        await into(dailyTaskCompletions).insert(
          DailyTaskCompletionsCompanion.insert(
            taskId: taskId,
            completedDate: today,
          ),
        );
      }
    } else {
      await (delete(dailyTaskCompletions)
            ..where((c) =>
                c.taskId.equals(taskId) &
                c.completedDate.isBiggerOrEqualValue(today) &
                c.completedDate.isSmallerThanValue(tomorrow)))
          .go();
    }
  }

  /// Returns the count of consecutive days (ending today or yesterday)
  /// where all enabled tasks were completed.
  Future<int> getDailyTaskStreak() async {
    final enabledCount = await (select(dailyTasks)
          ..where((t) => t.isEnabled.equals(true)))
        .get()
        .then((l) => l.length);
    if (enabledCount == 0) return 0;

    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    final completions = await (select(dailyTaskCompletions)
          ..where((c) => c.completedDate.isBiggerOrEqualValue(cutoff)))
        .get();

    final Map<DateTime, int> countByDay = {};
    for (final c in completions) {
      final d = c.completedDate;
      final day = DateTime(d.year, d.month, d.day);
      countByDay[day] = (countByDay[day] ?? 0) + 1;
    }

    final today = _todayStart();
    // If today is fully done, count from today; otherwise count from yesterday
    // so an in-progress day doesn't break the previous streak.
    DateTime check = (countByDay[today] ?? 0) >= enabledCount
        ? today
        : today.subtract(const Duration(days: 1));

    int streak = 0;
    while ((countByDay[check] ?? 0) >= enabledCount) {
      streak++;
      check = check.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Stream that re-emits the streak whenever any completion row changes.
  Stream<int> watchDailyTaskStreak() =>
      select(dailyTaskCompletions).watch().asyncMap((_) => getDailyTaskStreak());

  DateTime _todayStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
