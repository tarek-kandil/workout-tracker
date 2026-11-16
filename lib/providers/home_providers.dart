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

enum OverloadBucket { weightUp, repsOrTimeUp, held, dropped, firstTime }

class ExerciseOverloadItem {
  final Exercise exercise;
  final OverloadBucket bucket;
  final String currentSummary;
  final String? previousSummary;
  final String deltaLabel;
  final double? vsWeek1Pct;

  const ExerciseOverloadItem({
    required this.exercise,
    required this.bucket,
    required this.currentSummary,
    this.previousSummary,
    required this.deltaLabel,
    this.vsWeek1Pct,
  });
}

class ProgressiveOverloadSummary {
  final int weightUpCount;
  final int repsOrTimeUpCount;
  final int heldCount;
  final int droppedCount;
  final int firstTimeCount;
  final double? vsWeek1Pct;
  final List<({int week, double pctGain})> weekBars;
  final List<ExerciseOverloadItem> items;

  const ProgressiveOverloadSummary({
    required this.weightUpCount,
    required this.repsOrTimeUpCount,
    required this.heldCount,
    required this.droppedCount,
    required this.firstTimeCount,
    this.vsWeek1Pct,
    this.weekBars = const [],
    this.items = const [],
  });

  int get totalCompared =>
      weightUpCount + repsOrTimeUpCount + heldCount + droppedCount;

  int get progressedCount => weightUpCount + repsOrTimeUpCount;

  int get overloadRatePct =>
      totalCompared == 0 ? 0 : ((progressedCount / totalCompared) * 100).round();
}

String _fmtKg(double v) =>
    v == v.roundToDouble() ? '${v.toInt()} kg' : '${v.toStringAsFixed(1)} kg';

String _fmtSec(int sec) {
  final m = sec ~/ 60;
  final s = sec % 60;
  return m > 0 ? '${m}m ${s}s' : '${s}s';
}

final progressiveOverloadProvider =
    FutureProvider<ProgressiveOverloadSummary>((ref) async {
  final db = ref.watch(databaseProvider);
  ref.watch(pointsScoreProvider);
  final program = await ref.watch(activeProgramProvider.future);

  final allExercises = await db.exercisesDao.getAllExercises();
  final exerciseMap = {for (final e in allExercises) e.id: e};

  final now = DateTime.now();
  final sevenDaysAgo = now.subtract(const Duration(days: 7));
  final allSessions = await db.sessionsDao.getAllSessions(); // newest first
  final recentSessionIds = allSessions
      .where((s) => !s.date.isBefore(sevenDaysAgo))
      .map((s) => s.id)
      .toSet();

  // Map: exerciseId -> list of (sessionDate, sessionWeek, sets) ordered oldest -> newest
  final historyByExercise =
      <int, List<({int sessionId, DateTime date, int week, List<WorkoutSet> sets})>>{};

  for (final session in allSessions.reversed) {
    final sets = await db.setsDao.getSetsForSession(session.id);
    final byEx = <int, List<WorkoutSet>>{};
    for (final s in sets) {
      final ex = exerciseMap[s.exerciseId];
      if (ex == null) continue;
      final valid = ex.isTimed
          ? (s.durationSeconds ?? 0) > 0
          : (s.reps > 0 && s.weightKg > 0);
      if (!valid) continue;
      (byEx[s.exerciseId] ??= []).add(s);
    }
    for (final entry in byEx.entries) {
      (historyByExercise[entry.key] ??= []).add((
        sessionId: session.id,
        date: session.date,
        week: session.weekNumber ?? 1,
        sets: entry.value,
      ));
    }
  }

  double bestMetric(Exercise ex, List<WorkoutSet> sets) {
    if (ex.isTimed) {
      var best = 0;
      for (final s in sets) {
        final d = s.durationSeconds ?? 0;
        if (d > best) best = d;
      }
      return best.toDouble();
    } else {
      var best = 0.0;
      for (final s in sets) {
        final e1rm = s.weightKg * (1.0 + s.reps / 30.0);
        if (e1rm > best) best = e1rm;
      }
      return best;
    }
  }

  WorkoutSet bestWeightedSet(List<WorkoutSet> sets) {
    return sets.reduce((a, b) =>
        (a.weightKg * a.reps > b.weightKg * b.reps ||
                (a.weightKg * a.reps == b.weightKg * b.reps &&
                    a.weightKg >= b.weightKg))
            ? a
            : b);
  }

  // Program vs Week 1 calculation
  double? vsWeek1Pct;
  final weekBars = <({int week, double pctGain})>[];
  final exVsWeek1 = <int, double>{};

  if (program != null) {
    final programSessions =
        await db.sessionsDao.getSessionsForProgram(program.id);
    final programSessionIds = programSessions.map((s) => s.id).toSet();

    final pctGains = <double>[];
    final weekGainsMap = <int, List<double>>{};

    for (final entry in historyByExercise.entries) {
      final ex = exerciseMap[entry.key];
      if (ex == null) continue;
      final progLogs = entry.value
          .where((l) => programSessionIds.contains(l.sessionId))
          .toList();
      if (progLogs.isEmpty) continue;

      final baseline = bestMetric(ex, progLogs.first.sets);
      if (baseline <= 0) continue;

      for (final log in progLogs) {
        final m = bestMetric(ex, log.sets);
        final pct = ((m - baseline) / baseline) * 100.0;
        (weekGainsMap[log.week] ??= []).add(pct);
      }

      if (progLogs.length >= 2) {
        final latestMetric = bestMetric(ex, progLogs.last.sets);
        final gain = ((latestMetric - baseline) / baseline) * 100.0;
        pctGains.add(gain);
        exVsWeek1[ex.id] = gain;
      }
    }

    if (pctGains.isNotEmpty) {
      vsWeek1Pct =
          pctGains.reduce((a, b) => a + b) / pctGains.length;
    }

    final sortedWeeks = weekGainsMap.keys.toList()..sort();
    for (final w in sortedWeeks.reversed.take(5).toList().reversed) {
      final list = weekGainsMap[w]!;
      final avg = list.reduce((a, b) => a + b) / list.length;
      weekBars.add((week: w, pctGain: avg));
    }
  }

  int weightUp = 0;
  int repsOrTimeUp = 0;
  int held = 0;
  int dropped = 0;
  int firstTime = 0;
  final detailItems = <ExerciseOverloadItem>[];

  for (final entry in historyByExercise.entries) {
    final ex = exerciseMap[entry.key];
    if (ex == null) continue;
    final logs = entry.value;
    if (logs.isEmpty) continue;
    final latest = logs.last;
    if (!recentSessionIds.contains(latest.sessionId)) continue;

    if (logs.length < 2) {
      firstTime++;
      final String curSummary;
      if (ex.isTimed) {
        curSummary = _fmtSec(bestMetric(ex, latest.sets).round());
      } else {
        final curBest = bestWeightedSet(latest.sets);
        curSummary = '${_fmtKg(curBest.weightKg)} × ${curBest.reps}';
      }
      detailItems.add(ExerciseOverloadItem(
        exercise: ex,
        bucket: OverloadBucket.firstTime,
        currentSummary: curSummary,
        previousSummary: null,
        deltaLabel: 'Baseline',
        vsWeek1Pct: exVsWeek1[ex.id],
      ));
      continue;
    }
    final prev = logs[logs.length - 2];

    if (ex.isTimed) {
      final curDur = bestMetric(ex, latest.sets).round();
      final prevDur = bestMetric(ex, prev.sets).round();
      final diff = curDur - prevDur;
      final OverloadBucket bucket;
      final String deltaLabel;
      if (diff > 0) {
        repsOrTimeUp++;
        bucket = OverloadBucket.repsOrTimeUp;
        deltaLabel = '↑ +${diff}s';
      } else if (diff == 0) {
        held++;
        bucket = OverloadBucket.held;
        deltaLabel = '= Same time';
      } else {
        dropped++;
        bucket = OverloadBucket.dropped;
        deltaLabel = '↓ ${diff}s';
      }
      detailItems.add(ExerciseOverloadItem(
        exercise: ex,
        bucket: bucket,
        currentSummary: _fmtSec(curDur),
        previousSummary: _fmtSec(prevDur),
        deltaLabel: deltaLabel,
        vsWeek1Pct: exVsWeek1[ex.id],
      ));
    } else {
      final curBest = bestWeightedSet(latest.sets);
      final prevBest = bestWeightedSet(prev.sets);
      final curE1rm = bestMetric(ex, latest.sets);
      final prevE1rm = bestMetric(ex, prev.sets);
      final wDiff = curBest.weightKg - prevBest.weightKg;
      final rDiff = curBest.reps - prevBest.reps;

      final OverloadBucket bucket;
      final String deltaLabel;
      if (curBest.weightKg > prevBest.weightKg &&
          curBest.reps >= (prevBest.reps * 0.75).floor()) {
        weightUp++;
        bucket = OverloadBucket.weightUp;
        deltaLabel = '↑ +${_fmtKg(wDiff)}';
      } else if ((curBest.weightKg == prevBest.weightKg &&
              curBest.reps > prevBest.reps) ||
          curE1rm > prevE1rm + 0.01) {
        repsOrTimeUp++;
        bucket = OverloadBucket.repsOrTimeUp;
        deltaLabel = rDiff > 0 ? '↑ +$rDiff rep${rDiff == 1 ? '' : 's'}' : '↑ e1RM';
      } else if (curBest.weightKg == prevBest.weightKg &&
          curBest.reps == prevBest.reps) {
        held++;
        bucket = OverloadBucket.held;
        deltaLabel = '= Held';
      } else {
        dropped++;
        bucket = OverloadBucket.dropped;
        if (wDiff < 0) {
          deltaLabel = '↓ -${_fmtKg(wDiff.abs())}';
        } else {
          deltaLabel = '↓ $rDiff rep${rDiff.abs() == 1 ? '' : 's'}';
        }
      }
      detailItems.add(ExerciseOverloadItem(
        exercise: ex,
        bucket: bucket,
        currentSummary: '${_fmtKg(curBest.weightKg)} × ${curBest.reps}',
        previousSummary: '${_fmtKg(prevBest.weightKg)} × ${prevBest.reps}',
        deltaLabel: deltaLabel,
        vsWeek1Pct: exVsWeek1[ex.id],
      ));
    }
  }

  // Order detail items: dropped first (attention), then weightUp, repsOrTimeUp, held, firstTime
  int bucketOrder(OverloadBucket b) => switch (b) {
        OverloadBucket.dropped => 0,
        OverloadBucket.weightUp => 1,
        OverloadBucket.repsOrTimeUp => 2,
        OverloadBucket.held => 3,
        OverloadBucket.firstTime => 4,
      };
  detailItems.sort((a, b) {
    final c = bucketOrder(a.bucket).compareTo(bucketOrder(b.bucket));
    return c != 0 ? c : a.exercise.name.compareTo(b.exercise.name);
  });

  return ProgressiveOverloadSummary(
    weightUpCount: weightUp,
    repsOrTimeUpCount: repsOrTimeUp,
    heldCount: held,
    droppedCount: dropped,
    firstTimeCount: firstTime,
    vsWeek1Pct: vsWeek1Pct,
    weekBars: weekBars,
    items: detailItems,
  );
});
