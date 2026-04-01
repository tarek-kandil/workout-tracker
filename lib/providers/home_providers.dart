import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../models/weight_history_point.dart';
import 'database_provider.dart';
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
