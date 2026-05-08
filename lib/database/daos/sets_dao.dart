import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/sets_table.dart';
import '../tables/sessions_table.dart';
import '../../models/weight_history_point.dart';
import '../../models/personal_record_entry.dart';
import '../../models/weekly_pr_entry.dart';

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
                  r.read<int>('date') * 1000),
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

  /// Returns tonnage (kg), average RPE, total sets, and session count
  /// for sessions whose date falls within [from, to) (exclusive upper bound).
  /// Sets with null/zero weightKg are excluded from tonnage.
  /// Sets with null RPE are excluded from the RPE average.
  Future<({double tonnageKg, double? avgRpe, int totalSets, int sessionCount})>
      getWeeklyTonnageAndStats(DateTime from, DateTime to) async {
    final result = await customSelect(
      'SELECT '
      '  COALESCE(SUM(CASE WHEN ws.weight_kg > 0 THEN ws.reps * ws.weight_kg ELSE 0 END), 0.0) AS tonnage, '
      '  AVG(ws.rpe) AS avg_rpe, '
      '  COUNT(*) AS total_sets, '
      '  COUNT(DISTINCT ws.session_id) AS session_count '
      'FROM workout_sets ws '
      'JOIN workout_sessions s ON ws.session_id = s.id '
      'WHERE s.date >= ? AND s.date < ?',
      variables: [
        Variable.withInt(from.millisecondsSinceEpoch ~/ 1000),
        Variable.withInt(to.millisecondsSinceEpoch ~/ 1000),
      ],
      readsFrom: {workoutSets, workoutSessions},
    ).getSingle();

    return (
      tonnageKg: result.read<double>('tonnage'),
      avgRpe: result.read<double?>('avg_rpe'),
      totalSets: result.read<int>('total_sets'),
      sessionCount: result.read<int>('session_count'),
    );
  }

  /// Returns tonnage and set count grouped by exercise category
  /// for sessions within [from, to).
  /// Only counts sets with weight_kg > 0 for tonnage.
  Future<Map<String, ({double tonnageKg, int sets})>> getTonnageByCategory(
      DateTime from, DateTime to) async {
    final results = await customSelect(
      'SELECT e.category, '
      '  COALESCE(SUM(CASE WHEN ws.weight_kg > 0 THEN ws.reps * ws.weight_kg ELSE 0 END), 0.0) AS tonnage, '
      '  COUNT(*) AS sets '
      'FROM workout_sets ws '
      'JOIN workout_sessions s ON ws.session_id = s.id '
      'JOIN exercises e ON ws.exercise_id = e.id '
      'WHERE s.date >= ? AND s.date < ? '
      'GROUP BY e.category',
      variables: [
        Variable.withInt(from.millisecondsSinceEpoch ~/ 1000),
        Variable.withInt(to.millisecondsSinceEpoch ~/ 1000),
      ],
      readsFrom: {workoutSets, workoutSessions},
    ).get();

    return {
      for (final r in results)
        r.read<String>('category'): (
          tonnageKg: r.read<double>('tonnage'),
          sets: r.read<int>('sets'),
        ),
    };
  }

  /// Returns tonnage for each of [weekCount] calendar weeks ending at [weekEnd].
  /// Index 0 = oldest week, index [weekCount-1] = the week containing [weekEnd].
  Future<List<double>> getSparklineTonnage(
      DateTime weekEnd, int weekCount) async {
    assert(weekCount > 0 && weekCount <= 52, 'weekCount must be between 1 and 52');
    final results = <double>[];
    for (int i = weekCount - 1; i >= 0; i--) {
      final to = weekEnd.subtract(Duration(days: i * 7));
      final from = to.subtract(const Duration(days: 7));
      final stats = await getWeeklyTonnageAndStats(from, to);
      results.add(stats.tonnageKg);
    }
    return results;
  }

  /// Returns exercises where the max weight logged within [from, to) is
  /// strictly greater than the max weight logged before [from].
  /// Only applies to weighted (non-timed) exercises.
  Future<List<WeeklyPREntry>> getPRsBreakingThisWeek(
      DateTime from, DateTime to) async {
    final results = await customSelect(
      'SELECT e.name, '
      '  MAX(ws.weight_kg) AS this_week_max, '
      '  (SELECT ws3.reps '
      '   FROM workout_sets ws3 '
      '   JOIN workout_sessions s3 ON ws3.session_id = s3.id '
      '   WHERE ws3.exercise_id = ws.exercise_id '
      '     AND s3.date >= ? AND s3.date < ? '
      '   ORDER BY ws3.weight_kg DESC '
      '   LIMIT 1) AS reps '
      'FROM workout_sets ws '
      'JOIN workout_sessions s ON ws.session_id = s.id '
      'JOIN exercises e ON ws.exercise_id = e.id '
      'WHERE s.date >= ? AND s.date < ? '
      '  AND ws.weight_kg > 0 AND e.is_timed = 0 '
      'GROUP BY ws.exercise_id '
      'HAVING this_week_max > COALESCE(('
      '  SELECT MAX(ws2.weight_kg) '
      '  FROM workout_sets ws2 '
      '  JOIN workout_sessions s2 ON ws2.session_id = s2.id '
      '  WHERE ws2.exercise_id = ws.exercise_id AND s2.date < ?'
      '), -1)',
      variables: [
        Variable.withInt(from.millisecondsSinceEpoch ~/ 1000),
        Variable.withInt(to.millisecondsSinceEpoch ~/ 1000),
        Variable.withInt(from.millisecondsSinceEpoch ~/ 1000),
        Variable.withInt(to.millisecondsSinceEpoch ~/ 1000),
        Variable.withInt(from.millisecondsSinceEpoch ~/ 1000),
      ],
      readsFrom: {workoutSets, workoutSessions},
    ).get();

    return results
        .map((r) => WeeklyPREntry(
              exerciseName: r.read<String>('name'),
              weightKg: r.read<double>('this_week_max'),
              reps: r.read<int?>('reps') ?? 0,
            ))
        .toList();
  }
}
