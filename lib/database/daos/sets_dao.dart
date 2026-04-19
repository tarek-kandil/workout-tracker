import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/sets_table.dart';
import '../tables/sessions_table.dart';
import '../../models/weight_history_point.dart';
import '../../models/personal_record_entry.dart';

part 'sets_dao.g.dart';

@DriftAccessor(tables: [WorkoutSets, WorkoutSessions])
class SetsDao extends DatabaseAccessor<AppDatabase> with _$SetsDaoMixin {
  SetsDao(super.db);

  Future<int> insertSet(WorkoutSetsCompanion entry) =>
      into(workoutSets).insert(entry);

  Future<void> updateSet(WorkoutSetsCompanion entry) =>
      update(workoutSets).replace(entry);

  Future<void> deleteSet(int id) =>
      (delete(workoutSets)..where((s) => s.id.equals(id))).go();

  Future<void> deleteSetsForSession(int sessionId) =>
      (delete(workoutSets)..where((s) => s.sessionId.equals(sessionId))).go();

  Future<List<WorkoutSet>> getSetsForSession(int sessionId) =>
      (select(workoutSets)
            ..where((s) => s.sessionId.equals(sessionId))
            ..orderBy([
              (s) => OrderingTerm(expression: s.setNumber),
            ]))
          .get();

  /// Last sets for a given exercise in a specific WOD template.
  /// Returns sets from the single most-recent session of that WOD.
  /// Used to show reference weights and compute weight suggestions.
  Future<List<WorkoutSet>> getLastSetsForExerciseInWod(
      int exerciseId, int wodTemplateId) async {
    final query = select(workoutSets).join([
      innerJoin(workoutSessions,
          workoutSessions.id.equalsExp(workoutSets.sessionId)),
    ]);
    query
      ..where(workoutSets.exerciseId.equals(exerciseId))
      ..where(workoutSessions.wodTemplateId.equals(wodTemplateId))
      ..orderBy([
        OrderingTerm(
            expression: workoutSessions.date, mode: OrderingMode.desc),
        OrderingTerm(expression: workoutSets.setNumber),
      ]);

    final results = await query.get();
    if (results.isEmpty) return [];

    // Keep only sets from the most recent session
    final mostRecentSessionId =
        results.first.readTable(workoutSessions).id;
    return results
        .where((r) => r.readTable(workoutSessions).id == mostRecentSessionId)
        .map((r) => r.readTable(workoutSets))
        .toList();
  }

  /// Max weight per session for an exercise — used for the progress chart.
  Future<List<WeightHistoryPoint>> getWeightHistoryForExercise(
      int exerciseId, {int limit = 30}) async {
    final results = await customSelect(
      'SELECT s.date, MAX(ws.weight_kg) AS max_weight '
      'FROM workout_sets ws '
      'JOIN workout_sessions s ON ws.session_id = s.id '
      'WHERE ws.exercise_id = ? AND ws.weight_kg > 0 '
      'GROUP BY s.id '
      'ORDER BY s.date ASC '
      'LIMIT ?',
      variables: [Variable.withInt(exerciseId), Variable.withInt(limit)],
      readsFrom: {workoutSets, workoutSessions},
    ).get();

    return results
        .map((r) => WeightHistoryPoint(
              date: DateTime.fromMillisecondsSinceEpoch(
                  r.read<int>('date')),
              maxWeightKg: r.read<double>('max_weight'),
            ))
        .toList();
  }

  Future<void> clearAllSets() => delete(workoutSets).go();

  /// Delete all sets for a given exercise — resets its PR.
  Future<void> deleteSetsByExercise(int exerciseId) =>
      (delete(workoutSets)..where((s) => s.exerciseId.equals(exerciseId))).go();

  /// All exercises that have been logged, with their PR and estimated 1RM.
  /// Grouped by category then name. Used for the Records screen.
  Future<List<PersonalRecordEntry>> getAllPersonalRecords() async {
    final results = await customSelect(
      'SELECT e.id, e.name, e.category, e.is_timed, '
      'CASE WHEN e.is_timed = 0 THEN MAX(ws.weight_kg) ELSE 0.0 END AS max_weight, '
      'CASE WHEN e.is_timed = 0 THEN MAX(ws.weight_kg * (1.0 + CAST(ws.reps AS REAL) / 30.0)) ELSE 0.0 END AS max_1rm, '
      'CASE WHEN e.is_timed = 1 THEN MAX(ws.duration_seconds) ELSE NULL END AS max_duration '
      'FROM workout_sets ws '
      'JOIN exercises e ON ws.exercise_id = e.id '
      'WHERE (e.is_timed = 0 AND ws.reps > 0 AND ws.weight_kg > 0) '
      '   OR (e.is_timed = 1 AND ws.duration_seconds IS NOT NULL AND ws.duration_seconds > 0) '
      'GROUP BY ws.exercise_id '
      'ORDER BY e.category ASC, e.name ASC',
      readsFrom: {workoutSets},
    ).get();

    return results
        .map((r) => PersonalRecordEntry(
              exerciseId: r.read<int>('id'),
              exerciseName: r.read<String>('name'),
              exerciseCategory: r.read<String>('category'),
              isTimed: r.read<int>('is_timed') == 1,
              maxWeightKg: r.read<double>('max_weight'),
              estimatedOneRm: r.read<double>('max_1rm'),
              maxDurationSeconds: r.read<int?>('max_duration'),
            ))
        .toList();
  }

  /// Personal record (max weight) for a weighted exercise across all sessions.
  Future<double?> getPersonalRecord(int exerciseId) async {
    final result = await customSelect(
      'SELECT MAX(weight_kg) AS pr FROM workout_sets WHERE exercise_id = ?',
      variables: [Variable.withInt(exerciseId)],
      readsFrom: {workoutSets},
    ).getSingleOrNull();
    return result?.read<double?>('pr');
  }

  /// Personal record (max duration) for a timed exercise across all sessions.
  Future<int?> getPersonalRecordDuration(int exerciseId) async {
    final result = await customSelect(
      'SELECT MAX(duration_seconds) AS pr FROM workout_sets WHERE exercise_id = ?',
      variables: [Variable.withInt(exerciseId)],
      readsFrom: {workoutSets},
    ).getSingleOrNull();
    return result?.read<int?>('pr');
  }
}
