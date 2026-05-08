import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import 'database_provider.dart';

final dailyTasksProvider = StreamProvider<List<DailyTask>>((ref) {
  return ref.watch(databaseProvider).dailyTasksDao.watchAllTasks();
});

final todayCompletionsProvider = StreamProvider<Set<int>>((ref) {
  return ref
      .watch(databaseProvider)
      .dailyTasksDao
      .watchTodayCompletions()
      .map((list) => list.map((c) => c.taskId).toSet());
});

final dailyTaskStreakProvider = StreamProvider<int>((ref) {
  return ref.watch(databaseProvider).dailyTasksDao.watchDailyTaskStreak();
});

/// Last 7 days completion booleans for a specific task (index 0 = 6 days ago).
final taskLast7DaysProvider =
    StreamProvider.family<List<bool>, int>((ref, taskId) {
  return ref
      .watch(databaseProvider)
      .dailyTasksDao
      .watchLast7DaysForTask(taskId);
});

/// (completed, outOf) consistency for a task over the last 30 days.
final taskConsistencyProvider =
    FutureProvider.family<(int, int), int>((ref, taskId) {
  // Re-run whenever any completion changes
  ref.watch(todayCompletionsProvider);
  return ref
      .read(databaseProvider)
      .dailyTasksDao
      .getConsistencyForTask(taskId);
});
