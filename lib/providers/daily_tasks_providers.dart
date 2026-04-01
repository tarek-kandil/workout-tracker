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
