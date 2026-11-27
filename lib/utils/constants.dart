import 'package:drift/drift.dart';
import '../data/global_exercise_catalog.dart';
import '../database/app_database.dart';
import '../models/exercise_muscle_seed.dart';
import '../models/exercise_tracking_mode.dart';
import '../models/volume_landmark.dart';

export '../data/global_exercise_catalog.dart';

// ─── 21-muscle taxonomy (specs/003-muscle-volume-report) ──────────────────

/// Trainable muscles grouped by body region, in the fixed display order
/// used throughout the app (report, assignment picker, exercise library).
/// `Cardio` and `Full Body` are intentionally excluded — they remain
/// non-muscle training-style categories (FR-002).
const Map<String, List<String>> kMusclesByRegion = {
  'Chest': ['Chest'],
  'Back': ['Lats', 'Upper Back', 'Traps', 'Spinal Erectors'],
  'Shoulders': ['Front Delts', 'Side Delts', 'Rear Delts'],
  'Arms': ['Biceps', 'Triceps', 'Forearms'],
  'Legs': [
    'Quads', 'Hamstrings', 'Glutes', 'Adductors', 'Abductors',
    'Hip Flexors', 'Calves',
  ],
  'Core': ['Abs', 'Obliques'],
  'Neck': ['Neck'],
};

/// The 21 trainable muscles, flattened from [kMusclesByRegion] in display
/// order. This is the canonical membership list for muscle-volume reporting
/// and the muscle-assignment picker (FR-001).
final List<String> kTrainableMuscles = [
  for (final muscles in kMusclesByRegion.values) ...muscles,
];

/// Alias kept for the exercise-library chip grid, which historically used
/// this name for its selectable muscle list. Same 21 muscles as
/// [kTrainableMuscles].
List<String> get kMuscleGroups => kTrainableMuscles;

/// Non-muscle training-style categories. They may describe how an exercise
/// is trained but are excluded from hypertrophy landmarks and muscle-volume
/// status calculations (FR-002).
const List<String> kNonMuscleTrainingCategories = ['Cardio', 'Full Body'];

/// Returns the body region for a trainable muscle, or `null` if [muscle] is
/// not one of the 21 taxonomy muscles (e.g. a non-muscle category or a
/// not-yet-migrated legacy tag).
String? regionForMuscle(String muscle) {
  for (final entry in kMusclesByRegion.entries) {
    if (entry.value.contains(muscle)) return entry.key;
  }
  return null;
}

// ─── Volume landmarks (Intermediate defaults) ──────────────────────────────

/// Effective-set-per-role weights used by the weekly volume computation
/// (FR-008). Stored as code constants — not user-editable in this feature.
const String kMuscleRolePrimary = 'primary';
const String kMuscleRoleSecondary = 'secondary';

const Map<String, double> kMuscleRoleWeights = {
  kMuscleRolePrimary: 1.0,
  kMuscleRoleSecondary: 0.5,
};

/// Effective-set landmarks (MV/MEV/MAV/MRV) per sub-muscle per program
/// rotation / week. Calibrated for the 21 sub-muscle split so a standard
/// 1-rotation split reaches Optimal on trained muscles and flags excessive
/// single-muscle volume as Overtrained.
const Map<String, VolumeLandmark> kVolumeLandmarks = {
  'Chest': VolumeLandmark(mv: 2, mev: 3, mavLow: 6, mavHigh: 12, mrv: 16),
  'Lats': VolumeLandmark(mv: 2, mev: 3, mavLow: 6, mavHigh: 12, mrv: 16),
  'Upper Back': VolumeLandmark(mv: 2, mev: 3, mavLow: 6, mavHigh: 12, mrv: 16),
  'Traps': VolumeLandmark(mv: 1, mev: 1.5, mavLow: 3, mavHigh: 8, mrv: 12),
  'Spinal Erectors': VolumeLandmark(mv: 1, mev: 1.5, mavLow: 3, mavHigh: 8, mrv: 10),
  'Front Delts': VolumeLandmark(mv: 1, mev: 1.5, mavLow: 3, mavHigh: 8, mrv: 12),
  'Side Delts': VolumeLandmark(mv: 2, mev: 3, mavLow: 5, mavHigh: 10, mrv: 14),
  'Rear Delts': VolumeLandmark(mv: 1, mev: 1.5, mavLow: 3, mavHigh: 8, mrv: 12),
  'Biceps': VolumeLandmark(mv: 2, mev: 3, mavLow: 5, mavHigh: 10, mrv: 14),
  'Triceps': VolumeLandmark(mv: 2, mev: 3, mavLow: 5, mavHigh: 10, mrv: 14),
  'Forearms': VolumeLandmark(mv: 1, mev: 1.5, mavLow: 3, mavHigh: 7, mrv: 10),
  'Quads': VolumeLandmark(mv: 2, mev: 3, mavLow: 6, mavHigh: 12, mrv: 16),
  'Hamstrings': VolumeLandmark(mv: 2, mev: 3, mavLow: 5, mavHigh: 10, mrv: 14),
  'Glutes': VolumeLandmark(mv: 1, mev: 1.5, mavLow: 4, mavHigh: 9, mrv: 14),
  'Adductors': VolumeLandmark(mv: 1, mev: 1.5, mavLow: 3, mavHigh: 7, mrv: 10),
  'Abductors': VolumeLandmark(mv: 1, mev: 1.5, mavLow: 3, mavHigh: 7, mrv: 10),
  'Hip Flexors': VolumeLandmark(mv: 1, mev: 1.5, mavLow: 3, mavHigh: 7, mrv: 10),
  'Calves': VolumeLandmark(mv: 2, mev: 3, mavLow: 5, mavHigh: 10, mrv: 14),
  'Abs': VolumeLandmark(mv: 2, mev: 3, mavLow: 5, mavHigh: 10, mrv: 14),
  'Obliques': VolumeLandmark(mv: 1, mev: 1.5, mavLow: 3, mavHigh: 7, mrv: 10),
  'Neck': VolumeLandmark(mv: 0, mev: 1.5, mavLow: 3, mavHigh: 6, mrv: 9),
};

// ─── Legacy taxonomy (pre-v20; kept only for reference in tests/migration) ─

/// Legacy broad muscle tags used before schema v20. Exercises may still
/// carry these as inactive `exercise_muscles` rows after migration.
const List<String> kLegacyMuscleGroups = [
  'Chest', 'Back', 'Shoulders', 'Triceps', 'Biceps',
  'Front Delt', 'Rear Delt', 'Quads', 'Hamstrings',
  'Glutes', 'Core', 'Calves', 'Full Body', 'Cardio',
];

/// Default pure cardio/timed conditioning exercises. They intentionally have
/// no active muscle-volume assignments — Cardio remains a non-muscle
/// training-style category (FR-002).
final List<String> kDefaultCardioExerciseNames = [
  for (final seed in kGlobalExerciseCatalog)
    if (seed.isCardio) seed.name,
];

/// Canonical exercise name → role-aware muscle assignments (first entry is
/// always the single primary; the rest are optional secondaries), derived
/// from [kGlobalExerciseCatalog].
final Map<String, List<ExerciseMuscleSeed>> kExerciseMuscles = {
  for (final seed in kGlobalExerciseCatalog)
    if (!seed.isCardio && seed.muscles.isNotEmpty) seed.name: seed.muscles,
};

/// Full default exercise library derived from [kGlobalExerciseCatalog].
final List<ExercisesCompanion> kDefaultExercises = [
  for (final seed in kGlobalExerciseCatalog)
    ExercisesCompanion(
      name: Value(seed.name),
      canonicalKey: Value(seed.key),
      isTimed: Value(seed.mode == ExerciseTrackingMode.timed),
      trackingMode: Value(seed.mode.dbValue),
    ),
];
