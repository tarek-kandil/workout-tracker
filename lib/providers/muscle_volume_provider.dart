import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/daos/muscle_volume_dao.dart';
import '../models/weekly_muscle_volume.dart';
import '../providers/database_provider.dart';
import '../providers/exercise_providers.dart';
import '../utils/constants.dart';

/// Builds the 21-row Weekly Muscle Volume report from raw effective-set
/// totals: always includes every taxonomy muscle, defaulting missing rows
/// to 0.0 effective sets so a brand-new/empty database still renders the
/// full report (FR-014, SC-002).
List<WeeklyMuscleVolume> buildWeeklyMuscleVolumeReport(
  List<MuscleEffectiveSetRow> rows,
) {
  final byMuscle = {for (final row in rows) row.muscle: row};
  return [
    for (final muscle in kTrainableMuscles)
      WeeklyMuscleVolume.from(
        muscle: muscle,
        region: regionForMuscle(muscle) ?? '',
        effectiveSets: byMuscle[muscle]?.effectiveSets ?? 0.0,
        contributingSets: byMuscle[muscle]?.contributingSets ?? 0,
        landmark: kVolumeLandmarks[muscle]!,
      ),
  ];
}

/// Rolling 7-day window ending "now". Exposed as its own provider so tests
/// (and a future manual-refresh action) can override the window without
/// touching the DAO.
final muscleVolumeWindowProvider =
    Provider<({DateTime from, DateTime to})>((ref) {
  final to = DateTime.now();
  return (from: to.subtract(const Duration(days: 7)), to: to);
});

/// The Weekly Muscle Volume report: exactly 21 rows, one per taxonomy
/// muscle, in region-grouped display order (FR-007, FR-012, FR-014).
final weeklyMuscleVolumeProvider =
    FutureProvider<List<WeeklyMuscleVolume>>((ref) async {
  final db = ref.watch(databaseProvider);
  final window = ref.watch(muscleVolumeWindowProvider);
  final rows = await db.muscleVolumeDao
      .getRollingMuscleEffectiveSets(window.from, window.to);
  return buildWeeklyMuscleVolumeReport(rows);
});

/// Exercises that are "unmapped" for muscle-volume purposes: flagged during
/// migration/editing (`muscleNeedsReview`) or simply missing a primary
/// muscle assignment. Default cardio exercises are intentionally untracked
/// and excluded from this count. Drives the report's "N exercises need
/// muscle assignment" banner (design.md §4.4).
final unmappedExerciseCountProvider = FutureProvider<int>((ref) async {
  final allExercises = await ref.watch(exercisesProvider.future);
  final muscleMap = await ref.watch(exerciseMuscleMapProvider.future);

  var count = 0;
  for (final exercise in allExercises) {
    if (kDefaultCardioExerciseNames.contains(exercise.name)) continue;
    final assignments = muscleMap[exercise.id] ?? const [];
    final hasPrimary =
        assignments.any((m) => m.role == kMuscleRolePrimary);
    if (exercise.muscleNeedsReview || !hasPrimary) count++;
  }
  return count;
});

/// Computes planned effective sets per muscle across 1 full rotation of all
/// WOD templates in [phaseId] (standalone `targetSets` + circuit `rounds`).
Future<List<WeeklyMuscleVolume>> computePhaseMuscleVolume(
  AppDatabase db,
  int phaseId,
) async {
  final wods = await db.programsDao.getWodTemplatesForPhase(phaseId);
  final muscleMap = await db.exercisesDao.getAllMuscleAssignmentMap();

  final effectiveByMuscle = <String, double>{};
  final contributingByMuscle = <String, int>{};

  void addExerciseSets(int exerciseId, int sets) {
    if (sets <= 0) return;
    final assignments = muscleMap[exerciseId] ?? const <ExerciseMuscle>[];
    for (final a in assignments) {
      if (!a.isActive) continue;
      final weight = kMuscleRoleWeights[a.role] ?? 0.0;
      if (weight <= 0) continue;
      effectiveByMuscle[a.muscle] =
          (effectiveByMuscle[a.muscle] ?? 0.0) + sets * weight;
      contributingByMuscle[a.muscle] =
          (contributingByMuscle[a.muscle] ?? 0) + sets;
    }
  }

  for (final wod in wods) {
    final standalone = await db.programsDao.getTemplateExercises(wod.id);
    for (final te in standalone) {
      addExerciseSets(te.exerciseId, te.targetSets);
    }
    final groups = await db.programsDao.getGroupsForWod(wod.id);
    for (final g in groups) {
      final groupExs = await db.programsDao.getExercisesForGroup(g.id);
      for (final te in groupExs) {
        addExerciseSets(te.exerciseId, g.rounds);
      }
    }
  }

  final rows = [
    for (final m in effectiveByMuscle.keys)
      MuscleEffectiveSetRow(
        muscle: m,
        effectiveSets: effectiveByMuscle[m] ?? 0.0,
        contributingSets: contributingByMuscle[m] ?? 0,
      ),
  ];

  return buildWeeklyMuscleVolumeReport(rows);
}

final phaseMuscleVolumeProvider =
    FutureProvider.family<List<WeeklyMuscleVolume>, int>((ref, phaseId) async {
  final db = ref.watch(databaseProvider);
  ref.watch(exerciseMuscleMapProvider);
  return computePhaseMuscleVolume(db, phaseId);
});
