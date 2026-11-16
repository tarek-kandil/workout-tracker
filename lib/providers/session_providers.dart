import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';
import '../database/daos/sessions_dao.dart';
import '../database/daos/sets_dao.dart';
import '../models/personal_record_entry.dart';
import 'database_provider.dart';

class ExerciseLiftGoal {
  final int exerciseId;
  final double targetWeightKg;
  final int targetReps;

  const ExerciseLiftGoal({
    required this.exerciseId,
    required this.targetWeightKg,
    this.targetReps = 5,
  });

  double get targetOneRm => targetReps <= 1
      ? targetWeightKg
      : targetWeightKg * (1.0 + targetReps / 30.0);
}

const kExerciseGoalWeightPrefix = 'exercise_goal_';
const kExerciseGoalRepsPrefix = 'exercise_goal_reps_';

/// All user-defined exercise goals stored in SharedPreferences, keyed by exerciseId.
final exerciseGoalsProvider =
    FutureProvider<Map<int, ExerciseLiftGoal>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final goals = <int, ExerciseLiftGoal>{};
  for (final key in prefs.getKeys()) {
    if (key.startsWith(kExerciseGoalWeightPrefix) &&
        !key.startsWith(kExerciseGoalRepsPrefix)) {
      final idStr = key.substring(kExerciseGoalWeightPrefix.length);
      final id = int.tryParse(idStr);
      if (id == null) continue;
      final w = prefs.getDouble(key);
      if (w == null || w <= 0) continue;
      final r = prefs.getInt('$kExerciseGoalRepsPrefix$id') ?? 5;
      goals[id] = ExerciseLiftGoal(
        exerciseId: id,
        targetWeightKg: w,
        targetReps: r,
      );
    }
  }
  return goals;
});

Future<void> saveExerciseLiftGoal({
  required int exerciseId,
  required double targetWeightKg,
  required int targetReps,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble('$kExerciseGoalWeightPrefix$exerciseId', targetWeightKg);
  await prefs.setInt('$kExerciseGoalRepsPrefix$exerciseId', targetReps);
}

Future<void> removeExerciseLiftGoal(int exerciseId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('$kExerciseGoalWeightPrefix$exerciseId');
  await prefs.remove('$kExerciseGoalRepsPrefix$exerciseId');
}

/// Stream of all sessions, most recent first. Used by the History tab.
final recentSessionsProvider = StreamProvider<List<WorkoutSession>>((ref) {
  return ref.watch(databaseProvider).sessionsDao.watchRecentSessions(limit: 200);
});

/// Sessions with program name joined — used by the history screen.
final sessionHistoryProvider =
    StreamProvider<List<SessionWithProgram>>((ref) {
  return ref
      .watch(databaseProvider)
      .sessionsDao
      .watchSessionsWithProgram(limit: 200);
});

/// All exercises with at least one logged set, with PR and estimated 1RM.
final personalRecordsProvider =
    FutureProvider<List<PersonalRecordEntry>>((ref) {
  return ref.watch(databaseProvider).setsDao.getAllPersonalRecords();
});

/// Reactive stream of sets for a single session — used by session detail
/// so edits reflect immediately without a reload.
final setsForSessionProvider =
    StreamProvider.family<List<WorkoutSet>, int>((ref, sessionId) {
  return ref
      .watch(databaseProvider)
      .setsDao
      .watchSetsForSession(sessionId);
});

/// Batch stats (volume, sets, RIR, top weight, PR count) for every session.
/// Invalidated after any set edit or delete so the history list stays fresh.
final allSessionStatsProvider =
    FutureProvider<Map<int, SessionSetStats>>((ref) {
  return ref.watch(databaseProvider).setsDao.getAllSessionStats();
});
