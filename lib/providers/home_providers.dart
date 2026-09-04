import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../models/weight_history_point.dart';
import '../models/weekly_progress_data.dart';
import '../models/weekly_pr_entry.dart';
import 'database_provider.dart';
import 'daily_tasks_providers.dart';
import 'program_providers.dart';

/// Latest logged body weight entry.
final latestBodyweightProvider = StreamProvider<BodyweightEntry?>((ref) {
  return ref.watch(databaseProvider).bodyweightDao.watchLatestBodyweight();
});

/// Last 7 body weight entries for the sparkline (reactive stream).
final recentBodyweightsProvider =
    StreamProvider<List<BodyweightEntry>>((ref) {
  return ref.watch(databaseProvider).bodyweightDao.watchRecentBodyweights(7);
});

/// All body weight entries, most recent first — used in the log screen.
final allBodyweightsProvider = StreamProvider<List<BodyweightEntry>>((ref) {
  return ref.watch(databaseProvider).bodyweightDao.watchAllBodyweights();
});

/// Cumulative points score:
///   +1  per daily task completion (all time)
///   +5  per completed workout session
///   +10 per fully completed program week (all WODs done)
///
/// Reacts to task completions automatically; re-runs after sessions change
/// when [pointsScoreProvider] is invalidated from the session screens.
final pointsScoreProvider = FutureProvider<int>((ref) async {
  // Watch completions stream so score updates the moment a task is ticked
  ref.watch(todayCompletionsProvider);

  final db = ref.read(databaseProvider);
  final program = await ref.read(activeProgramProvider.future);

  final taskPoints = await db.dailyTasksDao.getTotalCompletionCount();
  final sessionCount = await db.sessionsDao.getTotalSessionCount();
  final sessionPoints = sessionCount * 5;

  int weekPoints = 0;
  if (program != null) {
    final phases = await db.programsDao.getPhasesForProgram(program.id);
    if (phases.isNotEmpty) {
      final wods =
          await db.programsDao.getWodTemplatesForPhase(phases.first.id);
      final wodsPerWeek = wods.isEmpty ? 1 : wods.length;
      final completeWeeks = await db.sessionsDao
          .getCompletedWeekCountForProgram(program.id, wodsPerWeek);
      weekPoints = completeWeeks * 10;
    }
  }

  return taskPoints + sessionPoints + weekPoints;
});

/// Consecutive complete weeks (all WODs done) immediately before the current week.
final workoutStreakProvider = FutureProvider<int>((ref) async {
  final program = await ref.watch(activeProgramProvider.future);
  if (program == null) return 0;

  final db = ref.watch(databaseProvider);
  final phases = await db.programsDao.getPhasesForProgram(program.id);
  if (phases.isEmpty) return 0;

  final firstSession =
      await db.sessionsDao.getFirstSessionForProgram(program.id);
  if (firstSession == null) return 0;

  final totalProgramWeeks =
      phases.fold(0, (sum, p) => sum + p.durationWeeks);
  final daysSinceStart =
      DateTime.now().difference(firstSession.date).inDays;
  final currentWeek =
      ((daysSinceStart / 7).floor() + 1).clamp(1, totalProgramWeeks);

  // Total WODs per week = total WODs across all phases / total weeks (assume uniform)
  // Simpler: use the total WODs in Phase 1 as the weekly target (most programs are uniform)
  final phase1Wods =
      await db.programsDao.getWodTemplatesForPhase(phases.first.id);
  final wodsPerWeek = phase1Wods.isEmpty ? 1 : phase1Wods.length;

  int streak = 0;
  for (int w = currentWeek - 1; w >= 1; w--) {
    final completed =
        await db.sessionsDao.getCompletedWodCountInWeek(program.id, w);
    if (completed >= wodsPerWeek) {
      streak++;
    } else {
      break;
    }
  }
  return streak;
});

/// Weight history for a given exercise — used by the strength chart card.
final strengthHistoryProvider =
    FutureProvider.family<List<WeightHistoryPoint>, int>(
        (ref, exerciseId) async {
  return ref
      .watch(databaseProvider)
      .setsDao
      .getWeightHistoryForExercise(exerciseId, limit: 20);
});

/// The exercise to show in the strength chart (user-configurable in a later slice).
/// For now defaults to the first exercise in the next WOD, if any.
final chartExerciseProvider = FutureProvider<Exercise?>((ref) async {
  final db = ref.watch(databaseProvider);
  final exercises = await db.exercisesDao.getAllExercises();
  // Default to first Push exercise (likely Bench Press)
  return exercises.where((e) => e.category == 'Push').firstOrNull ??
      exercises.firstOrNull;
});

DateTime _weekStart(DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  return d.subtract(Duration(days: d.weekday - 1));
}

final weeklyProgressProvider = FutureProvider<WeeklyProgressData>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final thisMonday = _weekStart(now);
  final nextMonday = thisMonday.add(const Duration(days: 7));
  final lastMonday = thisMonday.subtract(const Duration(days: 7));

  final results = await Future.wait([
    db.setsDao.getWeeklyTonnageAndStats(thisMonday, nextMonday),
    db.setsDao.getWeeklyTonnageAndStats(lastMonday, thisMonday),
  ]);
  final current = results[0];
  final last = results[1];

  final categories = await db.setsDao.getTonnageByCategory(thisMonday, nextMonday);
  final push = categories['Push'] ?? (tonnageKg: 0.0, sets: 0);
  final pull = categories['Pull'] ?? (tonnageKg: 0.0, sets: 0);
  final legs = categories['Legs'] ?? (tonnageKg: 0.0, sets: 0);

  final sparkline = await db.setsDao.getSparklineTonnage(nextMonday, 8);

  int plannedSessions = 3; // fallback: assume 3 sessions/week when no program is set
  final program = await ref.watch(activeProgramProvider.future);
  if (program != null) {
    final phases = await db.programsDao.getPhasesForProgram(program.id);
    if (phases.isNotEmpty) {
      final wods = await db.programsDao.getWodTemplatesForPhase(phases.first.id);
      if (wods.isNotEmpty) plannedSessions = wods.length;
    }
  }

  return WeeklyProgressData(
    tonnageKg: current.tonnageKg,
    lastWeekTonnageKg: last.tonnageKg,
    sparkline: sparkline,
    sessionCount: current.sessionCount,
    plannedSessions: plannedSessions,
    avgRir: current.avgRir,
    lastWeekAvgRir: last.avgRir,
    totalSets: current.totalSets,
    lastWeekTotalSets: last.totalSets,
    pushTonnageKg: push.tonnageKg,
    pullTonnageKg: pull.tonnageKg,
    legsTonnageKg: legs.tonnageKg,
    pushSets: push.sets,
    pullSets: pull.sets,
    legsSets: legs.sets,
  );
});

final weeklyPRsProvider = FutureProvider<List<WeeklyPREntry>>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final thisMonday = _weekStart(now);
  final nextMonday = thisMonday.add(const Duration(days: 7));
  return db.setsDao.getPRsBreakingThisWeek(thisMonday, nextMonday);
});
