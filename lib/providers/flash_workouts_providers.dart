import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../models/next_wod_result.dart';
import 'database_provider.dart';
import 'next_workout_provider.dart';
import 'session_providers.dart';

/// Stream of all active (non-archived) Flash Workouts (`phaseId IS NULL`).
final flashWorkoutsProvider = StreamProvider<List<WodTemplate>>((ref) {
  return ref.watch(databaseProvider).programsDao.watchFlashWorkouts();
});

/// Builds a [NextWodResult] for a standalone Flash Workout so it can be launched
/// directly in `ActiveSessionScreen` with full progressive overload, circuits,
/// and coaching notes support.
final flashWorkoutResultProvider =
    FutureProvider.family<NextWodResult?, int>((ref, wodTemplateId) async {
  // Recompute when sessions change so suggestions and lastSessionDate stay fresh.
  ref.watch(recentSessionsProvider);
  final db = ref.watch(databaseProvider);

  final wod = await (db.select(db.wodTemplates)
        ..where((w) => w.id.equals(wodTemplateId)))
      .getSingleOrNull();
  if (wod == null) return null;

  final allExercises = await db.exercisesDao.getAllExercises();
  final exerciseMap = {for (final e in allExercises) e.id: e};
  final items = await buildWodItems(db, wod.id, exerciseMap);
  final sessions = await db.sessionsDao.getSessionsForWodTemplate(wod.id);

  return NextWodResult(
    wodTemplate: wod,
    items: items,
    lastSessionDate: sessions.firstOrNull?.date,
  );
});

/// Last 7 days completion booleans for a Flash Workout (index 0 = 6 days ago, index 6 = today).
final flashWorkoutLast7DaysProvider =
    StreamProvider.family<List<bool>, int>((ref, wodTemplateId) {
  return ref
      .watch(databaseProvider)
      .sessionsDao
      .watchLast7DaysForWodTemplate(wodTemplateId);
});

/// (completedDays, outOfDays) consistency over the last 30 days for a Flash Workout.
final flashWorkoutConsistencyProvider =
    FutureProvider.family<(int, int), int>((ref, wodTemplateId) {
  ref.watch(recentSessionsProvider);
  return ref
      .read(databaseProvider)
      .sessionsDao
      .getConsistencyForWodTemplate(wodTemplateId);
});
