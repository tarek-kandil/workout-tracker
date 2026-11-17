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

  Future<void> setCompletion(int taskId, bool completed) =>
      setCompletionForDate(taskId, _todayStart(), completed);

  Future<void> setCompletionForDate(
      int taskId, DateTime date, bool completed) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final nextDay = dayStart.add(const Duration(days: 1));
    if (completed) {
      final existing = await (select(dailyTaskCompletions)
            ..where((c) =>
                c.taskId.equals(taskId) &
                c.completedDate.isBiggerOrEqualValue(dayStart) &
                c.completedDate.isSmallerThanValue(nextDay)))
          .getSingleOrNull();
      if (existing == null) {
        await into(dailyTaskCompletions).insert(
          DailyTaskCompletionsCompanion.insert(
            taskId: taskId,
            completedDate: dayStart,
          ),
        );
      }
    } else {
      await (delete(dailyTaskCompletions)
            ..where((c) =>
                c.taskId.equals(taskId) &
                c.completedDate.isBiggerOrEqualValue(dayStart) &
                c.completedDate.isSmallerThanValue(nextDay)))
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

  // ── Per-task consistency ──────────────────────────────────────────────────

  /// Total number of completion rows ever recorded.
  Future<int> getTotalCompletionCount() =>
      select(dailyTaskCompletions).get().then((l) => l.length);

  /// Stream of 7 booleans — one per day, index 0 = 6 days ago, index 6 = today.
  /// Reacts whenever a completion row for [taskId] changes.
  Stream<List<bool>> watchLast7DaysForTask(int taskId) {
    final today = _todayStart();
    final start = today.subtract(const Duration(days: 6));
    return (select(dailyTaskCompletions)
          ..where((c) =>
              c.taskId.equals(taskId) &
              c.completedDate.isBiggerOrEqualValue(start)))
        .watch()
        .map((completions) {
      final completedDays = completions
          .map((c) => DateTime(
              c.completedDate.year, c.completedDate.month, c.completedDate.day))
          .toSet();
      return List.generate(7, (i) {
        final day = today.subtract(Duration(days: 6 - i));
        return completedDays.contains(day);
      });
    });
  }

  /// (completed, outOf) for the last [days] calendar days.
  Future<(int, int)> getConsistencyForTask(int taskId,
      {int days = 30}) async {
    final today = _todayStart();
    final start = today.subtract(Duration(days: days - 1));
    final completions = await (select(dailyTaskCompletions)
          ..where((c) =>
              c.taskId.equals(taskId) &
              c.completedDate.isBiggerOrEqualValue(start)))
        .get();
    return (completions.length, days);
  }

  /// Live consistency stats for a single supplement/task:
  ///  - [streak]: consecutive days ending today or yesterday
  ///  - [last7Count]: completions in the last 7 rolling days
  ///  - [last30Count]: completions in the last 30 rolling days
  ///  - [thisWeekDone]: Mon..Sun (7 booleans) for the current calendar week
  Stream<({int streak, int last7Count, int last30Count, List<bool> thisWeekDone})>
      watchTaskConsistencyStats(int taskId) {
    final today = _todayStart();
    final cutoff90 = today.subtract(const Duration(days: 90));
    return (select(dailyTaskCompletions)
          ..where((c) =>
              c.taskId.equals(taskId) &
              c.completedDate.isBiggerOrEqualValue(cutoff90)))
        .watch()
        .map((rows) {
      final days = rows
          .map((c) => DateTime(
              c.completedDate.year, c.completedDate.month, c.completedDate.day))
          .toSet();

      var check = days.contains(today)
          ? today
          : today.subtract(const Duration(days: 1));
      var streak = 0;
      while (days.contains(check)) {
        streak++;
        check = check.subtract(const Duration(days: 1));
      }

      final start7 = today.subtract(const Duration(days: 6));
      final start30 = today.subtract(const Duration(days: 29));
      var last7 = 0;
      var last30 = 0;
      for (final d in days) {
        if (!d.isBefore(start7) && !d.isAfter(today)) last7++;
        if (!d.isBefore(start30) && !d.isAfter(today)) last30++;
      }

      final monday = today.subtract(Duration(days: today.weekday - 1));
      final thisWeekDone = List.generate(7, (i) {
        final d = monday.add(Duration(days: i));
        return days.contains(d);
      });

      return (
        streak: streak,
        last7Count: last7,
        last30Count: last30,
        thisWeekDone: thisWeekDone,
      );
    });
  }

  DateTime _todayStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
