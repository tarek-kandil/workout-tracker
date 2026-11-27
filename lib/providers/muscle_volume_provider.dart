import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/daos/muscle_volume_dao.dart';
import '../models/exercise_muscle_seed.dart';
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

/// Infers primary + secondary muscles from an exercise's name and category
/// when the exercise has no explicit active rows in `exercise_muscles`.
List<ExerciseMuscleSeed> inferMusclesForExercise(Exercise ex) {
  final canonicalName =
      kLegacyExerciseNameAliases[ex.name.toLowerCase()] ?? ex.name;
  for (final entry in kExerciseMuscles.entries) {
    if (entry.key.toLowerCase() == canonicalName.toLowerCase()) {
      return entry.value;
    }
  }
  final n = ex.name.toLowerCase();
  if (kDefaultCardioExerciseNames.any((c) => c.toLowerCase() == n)) {
    return const [];
  }

  if (n.contains('leg curl') || n.contains('hamstring')) {
    return const [ExerciseMuscleSeed.primary('Hamstrings')];
  }
  if (n.contains('rdl') || n.contains('romanian') || n.contains('stiff')) {
    return const [
      ExerciseMuscleSeed.primary('Hamstrings'),
      ExerciseMuscleSeed.secondary('Glutes'),
      ExerciseMuscleSeed.secondary('Spinal Erectors'),
    ];
  }
  if (n.contains('deadlift')) {
    return const [
      ExerciseMuscleSeed.primary('Spinal Erectors'),
      ExerciseMuscleSeed.secondary('Glutes'),
      ExerciseMuscleSeed.secondary('Hamstrings'),
      ExerciseMuscleSeed.secondary('Upper Back'),
      ExerciseMuscleSeed.secondary('Traps'),
    ];
  }
  if (n.contains('incline') && (n.contains('press') || n.contains('bench'))) {
    return const [
      ExerciseMuscleSeed.primary('Chest'),
      ExerciseMuscleSeed.secondary('Front Delts'),
      ExerciseMuscleSeed.secondary('Triceps'),
    ];
  }
  if (n.contains('bench') ||
      n.contains('chest press') ||
      n.contains('push-up') ||
      n.contains('pushup') ||
      n.contains('dip')) {
    return const [
      ExerciseMuscleSeed.primary('Chest'),
      ExerciseMuscleSeed.secondary('Triceps'),
      ExerciseMuscleSeed.secondary('Front Delts'),
    ];
  }
  if (n.contains('fly') || n.contains('pec')) {
    if (n.contains('reverse') || n.contains('rear')) {
      return const [
        ExerciseMuscleSeed.primary('Rear Delts'),
        ExerciseMuscleSeed.secondary('Upper Back'),
      ];
    }
    return const [
      ExerciseMuscleSeed.primary('Chest'),
      ExerciseMuscleSeed.secondary('Front Delts'),
    ];
  }
  if (n.contains('lat ') ||
      n.contains('pulldown') ||
      n.contains('pull-up') ||
      n.contains('pullup') ||
      n.contains('chin-up') ||
      n.contains('chinup')) {
    return const [
      ExerciseMuscleSeed.primary('Lats'),
      ExerciseMuscleSeed.secondary('Biceps'),
      ExerciseMuscleSeed.secondary('Upper Back'),
    ];
  }
  if (n.contains('row')) {
    if (n.contains('upright')) {
      return const [
        ExerciseMuscleSeed.primary('Side Delts'),
        ExerciseMuscleSeed.secondary('Traps'),
        ExerciseMuscleSeed.secondary('Rear Delts'),
      ];
    }
    return const [
      ExerciseMuscleSeed.primary('Upper Back'),
      ExerciseMuscleSeed.secondary('Lats'),
      ExerciseMuscleSeed.secondary('Biceps'),
      ExerciseMuscleSeed.secondary('Rear Delts'),
    ];
  }
  if (n.contains('shrug') || n.contains('trap')) {
    return const [ExerciseMuscleSeed.primary('Traps')];
  }
  if (n.contains('face pull') || n.contains('rear delt')) {
    return const [
      ExerciseMuscleSeed.primary('Rear Delts'),
      ExerciseMuscleSeed.secondary('Upper Back'),
      ExerciseMuscleSeed.secondary('Traps'),
    ];
  }
  if (n.contains('lateral') || n.contains('side raise')) {
    return const [ExerciseMuscleSeed.primary('Side Delts')];
  }
  if (n.contains('shoulder') ||
      n.contains('overhead') ||
      n.contains('military') ||
      n.contains('arnold') ||
      n.contains('front raise')) {
    return const [
      ExerciseMuscleSeed.primary('Front Delts'),
      ExerciseMuscleSeed.secondary('Side Delts'),
      ExerciseMuscleSeed.secondary('Triceps'),
    ];
  }
  if (n.contains('tricep') ||
      n.contains('pushdown') ||
      n.contains('skull')) {
    return const [ExerciseMuscleSeed.primary('Triceps')];
  }
  if (n.contains('curl')) {
    if (n.contains('hammer') || n.contains('reverse') || n.contains('wrist')) {
      return const [
        ExerciseMuscleSeed.primary('Biceps'),
        ExerciseMuscleSeed.secondary('Forearms'),
      ];
    }
    return const [ExerciseMuscleSeed.primary('Biceps')];
  }
  if (n.contains('squat') ||
      n.contains('leg press') ||
      n.contains('lunge') ||
      n.contains('split') ||
      n.contains('step-up')) {
    return const [
      ExerciseMuscleSeed.primary('Quads'),
      ExerciseMuscleSeed.secondary('Glutes'),
      ExerciseMuscleSeed.secondary('Hamstrings'),
      ExerciseMuscleSeed.secondary('Adductors'),
    ];
  }
  if (n.contains('leg extension') || n.contains('quad')) {
    return const [ExerciseMuscleSeed.primary('Quads')];
  }
  if (n.contains('hip thrust') ||
      n.contains('glute') ||
      n.contains('bridge') ||
      n.contains('kickback')) {
    return const [
      ExerciseMuscleSeed.primary('Glutes'),
      ExerciseMuscleSeed.secondary('Hamstrings'),
    ];
  }
  if (n.contains('adduct')) {
    return const [ExerciseMuscleSeed.primary('Adductors')];
  }
  if (n.contains('abduct')) {
    return const [ExerciseMuscleSeed.primary('Abductors')];
  }
  if (n.contains('calf') || n.contains('calves')) {
    return const [ExerciseMuscleSeed.primary('Calves')];
  }
  if (n.contains('oblique') ||
      n.contains('twist') ||
      n.contains('woodchop') ||
      n.contains('side plank')) {
    return const [
      ExerciseMuscleSeed.primary('Obliques'),
      ExerciseMuscleSeed.secondary('Abs'),
    ];
  }
  if (n.contains('ab') ||
      n.contains('plank') ||
      n.contains('crunch') ||
      n.contains('sit-up') ||
      n.contains('hollow') ||
      n.contains('leg raise') ||
      n.contains('core')) {
    return const [
      ExerciseMuscleSeed.primary('Abs'),
      ExerciseMuscleSeed.secondary('Obliques'),
    ];
  }

  // Fallback by legacy category
  return switch (ex.category.toLowerCase()) {
    'push' || 'chest' => const [
        ExerciseMuscleSeed.primary('Chest'),
        ExerciseMuscleSeed.secondary('Front Delts'),
        ExerciseMuscleSeed.secondary('Triceps'),
      ],
    'pull' || 'back' => const [
        ExerciseMuscleSeed.primary('Lats'),
        ExerciseMuscleSeed.secondary('Upper Back'),
        ExerciseMuscleSeed.secondary('Biceps'),
      ],
    'shoulders' => const [
        ExerciseMuscleSeed.primary('Side Delts'),
        ExerciseMuscleSeed.secondary('Front Delts'),
      ],
    'arms' => const [
        ExerciseMuscleSeed.primary('Biceps'),
        ExerciseMuscleSeed.secondary('Triceps'),
      ],
    'legs' => const [
        ExerciseMuscleSeed.primary('Quads'),
        ExerciseMuscleSeed.secondary('Hamstrings'),
        ExerciseMuscleSeed.secondary('Glutes'),
      ],
    'core' => const [
        ExerciseMuscleSeed.primary('Abs'),
        ExerciseMuscleSeed.secondary('Obliques'),
      ],
    _ => const [],
  };
}

/// Computes planned effective sets per muscle across 1 full rotation of all
/// WOD templates in [phaseId] (standalone `targetSets` + circuit `rounds`).
Future<List<WeeklyMuscleVolume>> computePhaseMuscleVolume(
  AppDatabase db,
  int phaseId,
) async {
  final wods = await db.programsDao.getWodTemplatesForPhase(phaseId);
  final muscleMap = await db.exercisesDao.getAllMuscleAssignmentMap();
  final allExercises = await db.exercisesDao.getAllExercisesIncludingArchived();
  final exerciseById = {for (final e in allExercises) e.id: e};

  final effectiveByMuscle = <String, double>{};
  final contributingByMuscle = <String, int>{};

  void addExerciseSets(int exerciseId, int sets) {
    if (sets <= 0) return;
    final ex = exerciseById[exerciseId];
    final assignments = muscleMap[exerciseId] ?? const <ExerciseMuscle>[];
    final activeValid = assignments
        .where((a) => a.isActive && kTrainableMuscles.contains(a.muscle))
        .toList();

    if (activeValid.isNotEmpty && !(ex?.muscleNeedsReview ?? false)) {
      for (final a in activeValid) {
        final weight = kMuscleRoleWeights[a.role] ?? 0.0;
        if (weight <= 0) continue;
        effectiveByMuscle[a.muscle] =
            (effectiveByMuscle[a.muscle] ?? 0.0) + sets * weight;
        contributingByMuscle[a.muscle] =
            (contributingByMuscle[a.muscle] ?? 0) + sets;
      }
      return;
    }

    // Fallback: infer from exercise name / category if unassigned or flagged for review
    if (ex == null) return;
    final inferred = inferMusclesForExercise(ex);
    if (inferred.isNotEmpty) {
      for (final seed in inferred) {
        final weight = seed.role == ExerciseMuscleRole.primary ? 1.0 : 0.5;
        effectiveByMuscle[seed.muscle] =
            (effectiveByMuscle[seed.muscle] ?? 0.0) + sets * weight;
        contributingByMuscle[seed.muscle] =
            (contributingByMuscle[seed.muscle] ?? 0) + sets;
      }
    } else {
      for (final a in activeValid) {
        final weight = kMuscleRoleWeights[a.role] ?? 0.0;
        if (weight <= 0) continue;
        effectiveByMuscle[a.muscle] =
            (effectiveByMuscle[a.muscle] ?? 0.0) + sets * weight;
        contributingByMuscle[a.muscle] =
            (contributingByMuscle[a.muscle] ?? 0) + sets;
      }
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
