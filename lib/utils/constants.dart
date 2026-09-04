import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../models/exercise_muscle_seed.dart';
import '../models/volume_landmark.dart';

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

/// Weekly effective-set landmarks (MV/MEV/MAV/MRV) per muscle, from the
/// spec's Intermediate landmark table. Code-owned, not stored in SQLite.
const Map<String, VolumeLandmark> kVolumeLandmarks = {
  'Chest': VolumeLandmark(mv: 4, mev: 8, mavLow: 12, mavHigh: 18, mrv: 22),
  'Lats': VolumeLandmark(mv: 4, mev: 8, mavLow: 12, mavHigh: 18, mrv: 22),
  'Upper Back': VolumeLandmark(mv: 4, mev: 8, mavLow: 12, mavHigh: 20, mrv: 24),
  'Traps': VolumeLandmark(mv: 2, mev: 6, mavLow: 10, mavHigh: 16, mrv: 20),
  'Spinal Erectors': VolumeLandmark(mv: 2, mev: 4, mavLow: 6, mavHigh: 10, mrv: 12),
  'Front Delts': VolumeLandmark(mv: 2, mev: 4, mavLow: 6, mavHigh: 10, mrv: 12),
  'Side Delts': VolumeLandmark(mv: 4, mev: 8, mavLow: 12, mavHigh: 20, mrv: 26),
  'Rear Delts': VolumeLandmark(mv: 4, mev: 8, mavLow: 12, mavHigh: 20, mrv: 24),
  'Biceps': VolumeLandmark(mv: 4, mev: 8, mavLow: 12, mavHigh: 18, mrv: 22),
  'Triceps': VolumeLandmark(mv: 4, mev: 8, mavLow: 12, mavHigh: 18, mrv: 22),
  'Forearms': VolumeLandmark(mv: 2, mev: 6, mavLow: 8, mavHigh: 14, mrv: 18),
  'Quads': VolumeLandmark(mv: 4, mev: 8, mavLow: 12, mavHigh: 18, mrv: 22),
  'Hamstrings': VolumeLandmark(mv: 4, mev: 8, mavLow: 10, mavHigh: 16, mrv: 20),
  'Glutes': VolumeLandmark(mv: 4, mev: 8, mavLow: 10, mavHigh: 18, mrv: 22),
  'Adductors': VolumeLandmark(mv: 2, mev: 4, mavLow: 6, mavHigh: 10, mrv: 14),
  'Abductors': VolumeLandmark(mv: 2, mev: 4, mavLow: 6, mavHigh: 10, mrv: 14),
  'Hip Flexors': VolumeLandmark(mv: 2, mev: 4, mavLow: 6, mavHigh: 10, mrv: 14),
  'Calves': VolumeLandmark(mv: 4, mev: 8, mavLow: 12, mavHigh: 20, mrv: 24),
  'Abs': VolumeLandmark(mv: 4, mev: 8, mavLow: 10, mavHigh: 16, mrv: 20),
  'Obliques': VolumeLandmark(mv: 2, mev: 6, mavLow: 8, mavHigh: 14, mrv: 18),
  'Neck': VolumeLandmark(mv: 0, mev: 2, mavLow: 4, mavHigh: 8, mrv: 10),
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
const List<String> kDefaultCardioExerciseNames = [
  'Treadmill Run',
  'Rowing Machine',
  'Jump Rope',
  'Assault Bike',
  'Stairmaster',
  'Cycling',
];

/// exercise name → role-aware muscle assignments (first entry is always the
/// single primary; the rest are optional secondaries). Used by first-launch
/// seeding (`muscles_seeded_v2`) to sync default exercises' active
/// `exercise_muscles` rows without deleting any legacy/user-edited rows.
///
/// Default cardio exercises ([kDefaultCardioExerciseNames]) are
/// intentionally absent from this map — they have no muscle-volume
/// assignment by default.
final Map<String, List<ExerciseMuscleSeed>> kExerciseMuscles = {
  // Chest
  'Bench Press': [
    const ExerciseMuscleSeed.primary('Chest'),
    const ExerciseMuscleSeed.secondary('Triceps'),
    const ExerciseMuscleSeed.secondary('Front Delts'),
  ],
  'Incline Bench Press': [
    const ExerciseMuscleSeed.primary('Chest'),
    const ExerciseMuscleSeed.secondary('Front Delts'),
    const ExerciseMuscleSeed.secondary('Triceps'),
  ],
  'Decline Bench Press': [
    const ExerciseMuscleSeed.primary('Chest'),
    const ExerciseMuscleSeed.secondary('Triceps'),
  ],
  'Dumbbell Fly': [
    const ExerciseMuscleSeed.primary('Chest'),
    const ExerciseMuscleSeed.secondary('Front Delts'),
  ],
  'Cable Fly': [
    const ExerciseMuscleSeed.primary('Chest'),
  ],
  'Pec Deck': [
    const ExerciseMuscleSeed.primary('Chest'),
  ],
  'Dips': [
    const ExerciseMuscleSeed.primary('Chest'),
    const ExerciseMuscleSeed.secondary('Triceps'),
    const ExerciseMuscleSeed.secondary('Front Delts'),
  ],
  'Push-ups': [
    const ExerciseMuscleSeed.primary('Chest'),
    const ExerciseMuscleSeed.secondary('Triceps'),
    const ExerciseMuscleSeed.secondary('Front Delts'),
  ],
  // Back
  'Deadlift': [
    const ExerciseMuscleSeed.primary('Spinal Erectors'),
    const ExerciseMuscleSeed.secondary('Glutes'),
    const ExerciseMuscleSeed.secondary('Hamstrings'),
    const ExerciseMuscleSeed.secondary('Traps'),
    const ExerciseMuscleSeed.secondary('Upper Back'),
  ],
  'Barbell Row': [
    const ExerciseMuscleSeed.primary('Upper Back'),
    const ExerciseMuscleSeed.secondary('Lats'),
    const ExerciseMuscleSeed.secondary('Biceps'),
    const ExerciseMuscleSeed.secondary('Rear Delts'),
  ],
  'Pull-ups': [
    const ExerciseMuscleSeed.primary('Lats'),
    const ExerciseMuscleSeed.secondary('Biceps'),
    const ExerciseMuscleSeed.secondary('Upper Back'),
  ],
  'Lat Pulldown': [
    const ExerciseMuscleSeed.primary('Lats'),
    const ExerciseMuscleSeed.secondary('Biceps'),
    const ExerciseMuscleSeed.secondary('Upper Back'),
  ],
  'Seated Cable Row': [
    const ExerciseMuscleSeed.primary('Upper Back'),
    const ExerciseMuscleSeed.secondary('Lats'),
    const ExerciseMuscleSeed.secondary('Biceps'),
    const ExerciseMuscleSeed.secondary('Rear Delts'),
  ],
  'T-Bar Row': [
    const ExerciseMuscleSeed.primary('Upper Back'),
    const ExerciseMuscleSeed.secondary('Lats'),
    const ExerciseMuscleSeed.secondary('Biceps'),
    const ExerciseMuscleSeed.secondary('Rear Delts'),
  ],
  'Single-Arm Dumbbell Row': [
    const ExerciseMuscleSeed.primary('Lats'),
    const ExerciseMuscleSeed.secondary('Upper Back'),
    const ExerciseMuscleSeed.secondary('Biceps'),
  ],
  'Chest-Supported Row': [
    const ExerciseMuscleSeed.primary('Upper Back'),
    const ExerciseMuscleSeed.secondary('Lats'),
    const ExerciseMuscleSeed.secondary('Rear Delts'),
    const ExerciseMuscleSeed.secondary('Biceps'),
  ],
  'Straight-Arm Pulldown': [
    const ExerciseMuscleSeed.primary('Lats'),
  ],
  // Shoulders
  'Overhead Press': [
    const ExerciseMuscleSeed.primary('Front Delts'),
    const ExerciseMuscleSeed.secondary('Side Delts'),
    const ExerciseMuscleSeed.secondary('Triceps'),
  ],
  'Dumbbell Shoulder Press': [
    const ExerciseMuscleSeed.primary('Front Delts'),
    const ExerciseMuscleSeed.secondary('Side Delts'),
    const ExerciseMuscleSeed.secondary('Triceps'),
  ],
  'Arnold Press': [
    const ExerciseMuscleSeed.primary('Front Delts'),
    const ExerciseMuscleSeed.secondary('Side Delts'),
    const ExerciseMuscleSeed.secondary('Triceps'),
  ],
  'Lateral Raises': [
    const ExerciseMuscleSeed.primary('Side Delts'),
  ],
  'Upright Row': [
    const ExerciseMuscleSeed.primary('Side Delts'),
    const ExerciseMuscleSeed.secondary('Traps'),
    const ExerciseMuscleSeed.secondary('Rear Delts'),
    const ExerciseMuscleSeed.secondary('Biceps'),
  ],
  'Front Raise': [
    const ExerciseMuscleSeed.primary('Front Delts'),
    const ExerciseMuscleSeed.secondary('Side Delts'),
  ],
  'Face Pulls': [
    const ExerciseMuscleSeed.primary('Rear Delts'),
    const ExerciseMuscleSeed.secondary('Traps'),
    const ExerciseMuscleSeed.secondary('Upper Back'),
  ],
  'Reverse Fly': [
    const ExerciseMuscleSeed.primary('Rear Delts'),
    const ExerciseMuscleSeed.secondary('Upper Back'),
  ],
  // Triceps
  'Tricep Pushdown': [
    const ExerciseMuscleSeed.primary('Triceps'),
  ],
  'Skull Crushers': [
    const ExerciseMuscleSeed.primary('Triceps'),
  ],
  'Close-Grip Bench Press': [
    const ExerciseMuscleSeed.primary('Triceps'),
    const ExerciseMuscleSeed.secondary('Chest'),
    const ExerciseMuscleSeed.secondary('Front Delts'),
  ],
  'Overhead Tricep Extension': [
    const ExerciseMuscleSeed.primary('Triceps'),
  ],
  'Tricep Kickback': [
    const ExerciseMuscleSeed.primary('Triceps'),
  ],
  // Biceps
  'Barbell Curl': [
    const ExerciseMuscleSeed.primary('Biceps'),
  ],
  'Dumbbell Curl': [
    const ExerciseMuscleSeed.primary('Biceps'),
  ],
  'Hammer Curl': [
    const ExerciseMuscleSeed.primary('Biceps'),
    const ExerciseMuscleSeed.secondary('Forearms'),
  ],
  'Preacher Curl': [
    const ExerciseMuscleSeed.primary('Biceps'),
  ],
  'Cable Curl': [
    const ExerciseMuscleSeed.primary('Biceps'),
  ],
  'Incline Dumbbell Curl': [
    const ExerciseMuscleSeed.primary('Biceps'),
  ],
  // Quads
  'Squat': [
    const ExerciseMuscleSeed.primary('Quads'),
    const ExerciseMuscleSeed.secondary('Glutes'),
    const ExerciseMuscleSeed.secondary('Hamstrings'),
    const ExerciseMuscleSeed.secondary('Abs'),
    const ExerciseMuscleSeed.secondary('Spinal Erectors'),
  ],
  'Leg Press': [
    const ExerciseMuscleSeed.primary('Quads'),
    const ExerciseMuscleSeed.secondary('Glutes'),
    const ExerciseMuscleSeed.secondary('Hamstrings'),
  ],
  'Leg Extension': [
    const ExerciseMuscleSeed.primary('Quads'),
  ],
  'Lunges': [
    const ExerciseMuscleSeed.primary('Quads'),
    const ExerciseMuscleSeed.secondary('Glutes'),
    const ExerciseMuscleSeed.secondary('Hamstrings'),
    const ExerciseMuscleSeed.secondary('Adductors'),
  ],
  'Hack Squat': [
    const ExerciseMuscleSeed.primary('Quads'),
    const ExerciseMuscleSeed.secondary('Glutes'),
  ],
  'Bulgarian Split Squat': [
    const ExerciseMuscleSeed.primary('Quads'),
    const ExerciseMuscleSeed.secondary('Glutes'),
    const ExerciseMuscleSeed.secondary('Hamstrings'),
    const ExerciseMuscleSeed.secondary('Adductors'),
  ],
  'Goblet Squat': [
    const ExerciseMuscleSeed.primary('Quads'),
    const ExerciseMuscleSeed.secondary('Glutes'),
    const ExerciseMuscleSeed.secondary('Abs'),
    const ExerciseMuscleSeed.secondary('Spinal Erectors'),
  ],
  'Front Squat': [
    const ExerciseMuscleSeed.primary('Quads'),
    const ExerciseMuscleSeed.secondary('Glutes'),
    const ExerciseMuscleSeed.secondary('Abs'),
    const ExerciseMuscleSeed.secondary('Spinal Erectors'),
  ],
  // Hamstrings
  'Romanian Deadlift': [
    const ExerciseMuscleSeed.primary('Hamstrings'),
    const ExerciseMuscleSeed.secondary('Glutes'),
    const ExerciseMuscleSeed.secondary('Spinal Erectors'),
  ],
  'Leg Curl': [
    const ExerciseMuscleSeed.primary('Hamstrings'),
  ],
  'Nordic Curl': [
    const ExerciseMuscleSeed.primary('Hamstrings'),
    const ExerciseMuscleSeed.secondary('Glutes'),
  ],
  'Stiff-Leg Deadlift': [
    const ExerciseMuscleSeed.primary('Hamstrings'),
    const ExerciseMuscleSeed.secondary('Glutes'),
    const ExerciseMuscleSeed.secondary('Spinal Erectors'),
  ],
  // Glutes
  'Hip Thrust': [
    const ExerciseMuscleSeed.primary('Glutes'),
    const ExerciseMuscleSeed.secondary('Hamstrings'),
  ],
  'Glute Bridge': [
    const ExerciseMuscleSeed.primary('Glutes'),
    const ExerciseMuscleSeed.secondary('Hamstrings'),
  ],
  'Sumo Squat': [
    const ExerciseMuscleSeed.primary('Glutes'),
    const ExerciseMuscleSeed.secondary('Quads'),
    const ExerciseMuscleSeed.secondary('Hamstrings'),
    const ExerciseMuscleSeed.secondary('Adductors'),
  ],
  'Cable Kickback': [
    const ExerciseMuscleSeed.primary('Glutes'),
  ],
  // Calves
  'Calf Raises': [
    const ExerciseMuscleSeed.primary('Calves'),
  ],
  'Seated Calf Raises': [
    const ExerciseMuscleSeed.primary('Calves'),
  ],
  // Core
  'Plank': [
    const ExerciseMuscleSeed.primary('Abs'),
    const ExerciseMuscleSeed.secondary('Obliques'),
  ],
  'Ab Wheel Rollout': [
    const ExerciseMuscleSeed.primary('Abs'),
    const ExerciseMuscleSeed.secondary('Lats'),
    const ExerciseMuscleSeed.secondary('Front Delts'),
  ],
  'Cable Crunch': [
    const ExerciseMuscleSeed.primary('Abs'),
  ],
  'Hanging Leg Raise': [
    const ExerciseMuscleSeed.primary('Abs'),
    const ExerciseMuscleSeed.secondary('Hip Flexors'),
  ],
  'Russian Twist': [
    const ExerciseMuscleSeed.primary('Obliques'),
    const ExerciseMuscleSeed.secondary('Abs'),
  ],
  'Dead Bug': [
    const ExerciseMuscleSeed.primary('Abs'),
    const ExerciseMuscleSeed.secondary('Hip Flexors'),
  ],
  'Side Plank': [
    const ExerciseMuscleSeed.primary('Obliques'),
    const ExerciseMuscleSeed.secondary('Abs'),
  ],
  'Decline Sit-up': [
    const ExerciseMuscleSeed.primary('Abs'),
    const ExerciseMuscleSeed.secondary('Hip Flexors'),
  ],
};

/// Full default exercise library (68 exercises). Inserted on first launch
/// and supplemented by the muscles_seeded_v1 / muscles_seeded_v2 passes.
final List<ExercisesCompanion> kDefaultExercises = [
  // Chest
  _ex('Bench Press'),
  _ex('Incline Bench Press'),
  _ex('Decline Bench Press'),
  _ex('Dumbbell Fly'),
  _ex('Cable Fly'),
  _ex('Pec Deck'),
  _ex('Dips'),
  _ex('Push-ups'),
  // Back
  _ex('Deadlift'),
  _ex('Barbell Row'),
  _ex('Pull-ups'),
  _ex('Lat Pulldown'),
  _ex('Seated Cable Row'),
  _ex('T-Bar Row'),
  _ex('Single-Arm Dumbbell Row'),
  _ex('Chest-Supported Row'),
  _ex('Straight-Arm Pulldown'),
  // Shoulders
  _ex('Overhead Press'),
  _ex('Dumbbell Shoulder Press'),
  _ex('Arnold Press'),
  _ex('Lateral Raises'),
  _ex('Upright Row'),
  // Front Delt
  _ex('Front Raise'),
  // Rear Delt
  _ex('Face Pulls'),
  _ex('Reverse Fly'),
  // Triceps
  _ex('Tricep Pushdown'),
  _ex('Skull Crushers'),
  _ex('Close-Grip Bench Press'),
  _ex('Overhead Tricep Extension'),
  _ex('Tricep Kickback'),
  // Biceps
  _ex('Barbell Curl'),
  _ex('Dumbbell Curl'),
  _ex('Hammer Curl'),
  _ex('Preacher Curl'),
  _ex('Cable Curl'),
  _ex('Incline Dumbbell Curl'),
  // Quads
  _ex('Squat'),
  _ex('Leg Press'),
  _ex('Leg Extension'),
  _ex('Lunges'),
  _ex('Hack Squat'),
  _ex('Bulgarian Split Squat'),
  _ex('Goblet Squat'),
  _ex('Front Squat'),
  // Hamstrings
  _ex('Romanian Deadlift'),
  _ex('Leg Curl'),
  _ex('Nordic Curl'),
  _ex('Stiff-Leg Deadlift'),
  // Glutes
  _ex('Hip Thrust'),
  _ex('Glute Bridge'),
  _ex('Sumo Squat'),
  _ex('Cable Kickback'),
  // Calves
  _ex('Calf Raises'),
  _ex('Seated Calf Raises'),
  // Core
  _ex('Plank'),
  _ex('Ab Wheel Rollout'),
  _ex('Cable Crunch'),
  _ex('Hanging Leg Raise'),
  _ex('Russian Twist'),
  _ex('Dead Bug'),
  _ex('Side Plank'),
  _ex('Decline Sit-up'),
  // Cardio (timed)
  _ex('Treadmill Run', timed: true),
  _ex('Rowing Machine', timed: true),
  _ex('Jump Rope', timed: true),
  _ex('Assault Bike', timed: true),
  _ex('Stairmaster', timed: true),
  _ex('Cycling', timed: true),
];

ExercisesCompanion _ex(String name, {bool timed = false}) =>
    ExercisesCompanion(
      name: Value(name),
      isTimed: Value(timed),
    );
