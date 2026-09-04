import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/sets_table.dart';
import '../tables/sessions_table.dart';
import '../tables/exercises_table.dart';
import '../tables/exercise_muscles_table.dart';
import '../../utils/constants.dart';

part 'muscle_volume_dao.g.dart';

/// One muscle's raw rolling-window aggregate, before landmark/status
/// classification (see [WeeklyMuscleVolume] in
/// lib/models/weekly_muscle_volume.dart for the classified report row).
class MuscleEffectiveSetRow {
  final String muscle;
  final double effectiveSets;
  final int contributingSets;
  const MuscleEffectiveSetRow({
    required this.muscle,
    required this.effectiveSets,
    required this.contributingSets,
  });
}

/// Aggregation queries for the Weekly Muscle Volume report
/// (specs/003-muscle-volume-report). Straight sets and circuit sets are
/// both persisted as `workout_sets` rows keyed by `exercise_id`, so a single
/// query counts both identically — no join to circuit template tables is
/// needed (see data-model.md "Circuits").
@DriftAccessor(tables: [WorkoutSets, WorkoutSessions, Exercises, ExerciseMuscles])
class MuscleVolumeDao extends DatabaseAccessor<AppDatabase>
    with _$MuscleVolumeDaoMixin {
  MuscleVolumeDao(super.db);

  /// Effective sets per active taxonomy muscle for completed sets whose
  /// session date falls in `[from, to)`.
  ///
  /// Credit per contributing (set, muscle-assignment) pair:
  ///   roleWeight     = primary ? 1.0 : 0.5
  ///   rirMultiplier  = (rir != null && rir >= 5.0) ? 0.5 : 1.0
  ///   credit         = roleWeight * rirMultiplier
  ///
  /// Only active (`is_active = 1`) assignments to one of the 21 trainable
  /// muscles are counted — legacy/inactive rows and non-muscle categories
  /// (Cardio, Full Body) never contribute (FR-002, FR-017).
  Future<List<MuscleEffectiveSetRow>> getRollingMuscleEffectiveSets(
    DateTime from,
    DateTime to,
  ) async {
    final placeholders =
        List.filled(kTrainableMuscles.length, '?').join(',');

    final results = await customSelect(
      'SELECT '
      '  em.muscle AS muscle, '
      '  COALESCE(SUM('
      '    CASE em.role WHEN ? THEN 1.0 WHEN ? THEN 0.5 ELSE '
      '      CASE WHEN em.sort_order = 0 THEN 1.0 ELSE 0.5 END '
      '    END '
      '    * '
      '    CASE WHEN ws.rir IS NOT NULL AND ws.rir >= 5.0 THEN 0.5 ELSE 1.0 END'
      '  ), 0.0) AS effective_sets, '
      '  COUNT(*) AS contributing_sets '
      'FROM workout_sets ws '
      'JOIN workout_sessions s ON s.id = ws.session_id '
      'JOIN exercises e ON e.id = ws.exercise_id '
      'JOIN exercise_muscles em ON em.exercise_id = ws.exercise_id '
      'WHERE s.date >= ? AND s.date < ? '
      '  AND em.is_active = 1 '
      '  AND em.muscle IN ($placeholders) '
      '  AND ('
      '    (e.is_timed = 1 AND COALESCE(ws.duration_seconds, 0) > 0) '
      '    OR (e.is_timed = 0 AND ws.reps > 0)'
      '  ) '
      'GROUP BY em.muscle',
      variables: [
        Variable.withString(kMuscleRolePrimary),
        Variable.withString(kMuscleRoleSecondary),
        Variable.withInt(from.millisecondsSinceEpoch ~/ 1000),
        Variable.withInt(to.millisecondsSinceEpoch ~/ 1000),
        for (final muscle in kTrainableMuscles) Variable.withString(muscle),
      ],
      readsFrom: {workoutSets, workoutSessions, exercises, exerciseMuscles},
    ).get();

    return results
        .map((r) => MuscleEffectiveSetRow(
              muscle: r.read<String>('muscle'),
              effectiveSets: r.read<double>('effective_sets'),
              contributingSets: r.read<int>('contributing_sets'),
            ))
        .toList();
  }
}
