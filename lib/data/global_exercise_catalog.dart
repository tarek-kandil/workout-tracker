import '../models/exercise_muscle_seed.dart';
import '../models/exercise_tracking_mode.dart';

/// Canonical definition of one exercise in the Global Exercise Catalog v1.
///
/// [key] is permanent and snake_case — used to derive deterministic UUID v5
/// identifiers for the backend global library so display-name tweaks never
/// orphan workout history.
class GlobalExerciseSeed {
  final String key;
  final String name;
  final ExerciseTrackingMode mode;
  final List<ExerciseMuscleSeed> muscles;
  final List<String> legacyNames;
  final bool isCardio;

  const GlobalExerciseSeed({
    required this.key,
    required this.name,
    this.mode = ExerciseTrackingMode.weightedReps,
    this.muscles = const [],
    this.legacyNames = const [],
    this.isCardio = false,
  });
}

const ExerciseMuscleSeed _pChest = ExerciseMuscleSeed.primary('Chest');
const ExerciseMuscleSeed _sChest = ExerciseMuscleSeed.secondary('Chest');
const ExerciseMuscleSeed _pLats = ExerciseMuscleSeed.primary('Lats');
const ExerciseMuscleSeed _sLats = ExerciseMuscleSeed.secondary('Lats');
const ExerciseMuscleSeed _pUpperBack = ExerciseMuscleSeed.primary('Upper Back');
const ExerciseMuscleSeed _sUpperBack = ExerciseMuscleSeed.secondary('Upper Back');
const ExerciseMuscleSeed _pTraps = ExerciseMuscleSeed.primary('Traps');
const ExerciseMuscleSeed _sTraps = ExerciseMuscleSeed.secondary('Traps');
const ExerciseMuscleSeed _pErectors = ExerciseMuscleSeed.primary('Spinal Erectors');
const ExerciseMuscleSeed _sErectors = ExerciseMuscleSeed.secondary('Spinal Erectors');
const ExerciseMuscleSeed _pFrontDelts = ExerciseMuscleSeed.primary('Front Delts');
const ExerciseMuscleSeed _sFrontDelts = ExerciseMuscleSeed.secondary('Front Delts');
const ExerciseMuscleSeed _pSideDelts = ExerciseMuscleSeed.primary('Side Delts');
const ExerciseMuscleSeed _sSideDelts = ExerciseMuscleSeed.secondary('Side Delts');
const ExerciseMuscleSeed _pRearDelts = ExerciseMuscleSeed.primary('Rear Delts');
const ExerciseMuscleSeed _sRearDelts = ExerciseMuscleSeed.secondary('Rear Delts');
const ExerciseMuscleSeed _pTriceps = ExerciseMuscleSeed.primary('Triceps');
const ExerciseMuscleSeed _sTriceps = ExerciseMuscleSeed.secondary('Triceps');
const ExerciseMuscleSeed _pBiceps = ExerciseMuscleSeed.primary('Biceps');
const ExerciseMuscleSeed _sBiceps = ExerciseMuscleSeed.secondary('Biceps');
const ExerciseMuscleSeed _pForearms = ExerciseMuscleSeed.primary('Forearms');
const ExerciseMuscleSeed _sForearms = ExerciseMuscleSeed.secondary('Forearms');
const ExerciseMuscleSeed _pQuads = ExerciseMuscleSeed.primary('Quads');
const ExerciseMuscleSeed _sQuads = ExerciseMuscleSeed.secondary('Quads');
const ExerciseMuscleSeed _pHamstrings = ExerciseMuscleSeed.primary('Hamstrings');
const ExerciseMuscleSeed _sHamstrings = ExerciseMuscleSeed.secondary('Hamstrings');
const ExerciseMuscleSeed _pGlutes = ExerciseMuscleSeed.primary('Glutes');
const ExerciseMuscleSeed _sGlutes = ExerciseMuscleSeed.secondary('Glutes');
const ExerciseMuscleSeed _pAdductors = ExerciseMuscleSeed.primary('Adductors');
const ExerciseMuscleSeed _sAdductors = ExerciseMuscleSeed.secondary('Adductors');
const ExerciseMuscleSeed _pAbductors = ExerciseMuscleSeed.primary('Abductors');
const ExerciseMuscleSeed _pHipFlexors = ExerciseMuscleSeed.primary('Hip Flexors');
const ExerciseMuscleSeed _sHipFlexors = ExerciseMuscleSeed.secondary('Hip Flexors');
const ExerciseMuscleSeed _pCalves = ExerciseMuscleSeed.primary('Calves');
const ExerciseMuscleSeed _pAbs = ExerciseMuscleSeed.primary('Abs');
const ExerciseMuscleSeed _sAbs = ExerciseMuscleSeed.secondary('Abs');
const ExerciseMuscleSeed _pObliques = ExerciseMuscleSeed.primary('Obliques');
const ExerciseMuscleSeed _sObliques = ExerciseMuscleSeed.secondary('Obliques');
const ExerciseMuscleSeed _pNeck = ExerciseMuscleSeed.primary('Neck');

/// Complete Global Exercise Catalog v1 (181 exercises across all 21 trainable
/// muscles + 8 non-muscle Cardio conditioning exercises).
const List<GlobalExerciseSeed> kGlobalExerciseCatalog = [
  // ── Chest (18) ─────────────────────────────────────────────────────────────
  GlobalExerciseSeed(
    key: 'bench_press',
    name: 'Bench Press',
    muscles: [_pChest, _sTriceps, _sFrontDelts],
  ),
  GlobalExerciseSeed(
    key: 'wide_grip_bench_press',
    name: 'Wide-Grip Bench Press',
    muscles: [_pChest, _sFrontDelts, _sTriceps],
  ),
  GlobalExerciseSeed(
    key: 'db_bench_press',
    name: 'DB Bench Press',
    muscles: [_pChest, _sTriceps, _sFrontDelts],
  ),
  GlobalExerciseSeed(
    key: 'neutral_grip_db_bench_press',
    name: 'Neutral-Grip DB Bench Press',
    muscles: [_pChest, _sTriceps, _sFrontDelts],
  ),
  GlobalExerciseSeed(
    key: 'smith_machine_bench_press',
    name: 'Smith Machine Bench Press',
    muscles: [_pChest, _sTriceps, _sFrontDelts],
  ),
  GlobalExerciseSeed(
    key: 'incline_bench_press',
    name: 'Incline Bench Press',
    muscles: [_pChest, _sFrontDelts, _sTriceps],
  ),
  GlobalExerciseSeed(
    key: 'incline_db_bench_press',
    name: 'Incline DB Bench Press',
    muscles: [_pChest, _sFrontDelts, _sTriceps],
  ),
  GlobalExerciseSeed(
    key: 'smith_machine_incline_bench_press',
    name: 'Smith Machine Incline Bench Press',
    muscles: [_pChest, _sFrontDelts, _sTriceps],
  ),
  GlobalExerciseSeed(
    key: 'decline_bench_press',
    name: 'Decline Bench Press',
    muscles: [_pChest, _sTriceps],
  ),
  GlobalExerciseSeed(
    key: 'machine_chest_press',
    name: 'Machine Chest Press',
    muscles: [_pChest, _sTriceps, _sFrontDelts],
  ),
  GlobalExerciseSeed(
    key: 'db_flys',
    name: 'DB Flys',
    muscles: [_pChest],
    legacyNames: ['Dumbbell Fly'],
  ),
  GlobalExerciseSeed(
    key: 'cable_flys',
    name: 'Cable Flys',
    muscles: [_pChest],
    legacyNames: ['Cable Fly'],
  ),
  GlobalExerciseSeed(
    key: 'low_to_high_cable_flys',
    name: 'Low-To-High Cable Flys',
    muscles: [_pChest, _sFrontDelts],
  ),
  GlobalExerciseSeed(
    key: 'pec_deck',
    name: 'Pec Deck',
    muscles: [_pChest],
  ),
  GlobalExerciseSeed(
    key: 'dips',
    name: 'Dips',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pChest, _sTriceps, _sFrontDelts],
  ),
  GlobalExerciseSeed(
    key: 'weighted_dips',
    name: 'Weighted Dips',
    muscles: [_pChest, _sTriceps, _sFrontDelts],
  ),
  GlobalExerciseSeed(
    key: 'push_ups',
    name: 'Push-Ups',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pChest, _sTriceps, _sFrontDelts],
    legacyNames: ['Push-ups'],
  ),
  GlobalExerciseSeed(
    key: 'wide_grip_push_ups',
    name: 'Wide-Grip Push-Ups',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pChest, _sFrontDelts, _sTriceps],
  ),

  // ── Back — Lats (18) ───────────────────────────────────────────────────────
  GlobalExerciseSeed(
    key: 'pull_ups',
    name: 'Pull-Ups',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pLats, _sBiceps, _sUpperBack],
    legacyNames: ['Pull-ups'],
  ),
  GlobalExerciseSeed(
    key: 'wide_grip_pull_ups',
    name: 'Wide-Grip Pull-Ups',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pLats, _sUpperBack, _sBiceps],
  ),
  GlobalExerciseSeed(
    key: 'neutral_grip_pull_ups',
    name: 'Neutral-Grip Pull-Ups',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pLats, _sBiceps, _sForearms, _sUpperBack],
  ),
  GlobalExerciseSeed(
    key: 'weighted_pull_ups',
    name: 'Weighted Pull-Ups',
    muscles: [_pLats, _sBiceps, _sUpperBack],
    legacyNames: ['Weighted Pull-ups'],
  ),
  GlobalExerciseSeed(
    key: 'weighted_neutral_grip_pull_ups',
    name: 'Weighted Neutral-Grip Pull-Ups',
    muscles: [_pLats, _sBiceps, _sForearms, _sUpperBack],
  ),
  GlobalExerciseSeed(
    key: 'chin_ups',
    name: 'Chin-Ups',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pLats, _sBiceps, _sUpperBack],
    legacyNames: ['Chin-ups'],
  ),
  GlobalExerciseSeed(
    key: 'weighted_chin_ups',
    name: 'Weighted Chin-Ups',
    muscles: [_pLats, _sBiceps, _sUpperBack],
  ),
  GlobalExerciseSeed(
    key: 'lat_pulldowns',
    name: 'Lat Pulldowns',
    muscles: [_pLats, _sBiceps, _sUpperBack],
    legacyNames: ['Lat Pulldown'],
  ),
  GlobalExerciseSeed(
    key: 'wide_grip_lat_pulldowns',
    name: 'Wide-Grip Lat Pulldowns',
    muscles: [_pLats, _sUpperBack, _sBiceps],
  ),
  GlobalExerciseSeed(
    key: 'neutral_grip_lat_pulldowns',
    name: 'Neutral-Grip Lat Pulldowns',
    muscles: [_pLats, _sBiceps, _sUpperBack],
  ),
  GlobalExerciseSeed(
    key: 'close_grip_lat_pulldowns',
    name: 'Close-Grip Lat Pulldowns',
    muscles: [_pLats, _sBiceps, _sUpperBack],
  ),
  GlobalExerciseSeed(
    key: 'underhand_lat_pulldowns',
    name: 'Underhand Lat Pulldowns',
    muscles: [_pLats, _sBiceps, _sUpperBack],
  ),
  GlobalExerciseSeed(
    key: 'single_arm_db_rows',
    name: 'Single-Arm DB Rows',
    muscles: [_pLats, _sUpperBack, _sBiceps],
    legacyNames: ['Single-Arm Dumbbell Row'],
  ),
  GlobalExerciseSeed(
    key: 'single_arm_cable_rows',
    name: 'Single-Arm Cable Rows',
    muscles: [_pLats, _sUpperBack, _sBiceps],
  ),
  GlobalExerciseSeed(
    key: 'meadows_rows',
    name: 'Meadows Rows',
    muscles: [_pLats, _sUpperBack, _sRearDelts, _sBiceps, _sForearms],
  ),
  GlobalExerciseSeed(
    key: 'underhand_bb_rows',
    name: 'Underhand BB Rows',
    muscles: [_pLats, _sUpperBack, _sBiceps, _sErectors],
  ),
  GlobalExerciseSeed(
    key: 'straight_arm_pulldowns',
    name: 'Straight-Arm Pulldowns',
    muscles: [_pLats],
    legacyNames: ['Straight-Arm Pulldown'],
  ),
  GlobalExerciseSeed(
    key: 'db_pullovers',
    name: 'DB Pullovers',
    muscles: [_pLats, _sChest],
  ),

  // ── Back — Upper Back, Traps & Spinal Erectors (20) ────────────────────────
  GlobalExerciseSeed(
    key: 'bb_rows',
    name: 'BB Rows',
    muscles: [_pUpperBack, _sLats, _sBiceps, _sRearDelts, _sErectors],
    legacyNames: ['Barbell Row'],
  ),
  GlobalExerciseSeed(
    key: 'wide_grip_bb_rows',
    name: 'Wide-Grip BB Rows',
    muscles: [_pUpperBack, _sRearDelts, _sTraps, _sBiceps, _sErectors],
  ),
  GlobalExerciseSeed(
    key: 'pendlay_rows',
    name: 'Pendlay Rows',
    muscles: [_pUpperBack, _sLats, _sBiceps, _sRearDelts, _sErectors],
  ),
  GlobalExerciseSeed(
    key: 'smith_machine_rows',
    name: 'Smith Machine Rows',
    muscles: [_pUpperBack, _sLats, _sBiceps, _sRearDelts],
  ),
  GlobalExerciseSeed(
    key: 'seated_cable_rows',
    name: 'Seated Cable Rows',
    muscles: [_pUpperBack, _sLats, _sBiceps, _sRearDelts],
    legacyNames: ['Seated Cable Row'],
  ),
  GlobalExerciseSeed(
    key: 'wide_grip_seated_cable_rows',
    name: 'Wide-Grip Seated Cable Rows',
    muscles: [_pUpperBack, _sRearDelts, _sTraps, _sBiceps],
  ),
  GlobalExerciseSeed(
    key: 'close_grip_seated_cable_rows',
    name: 'Close-Grip Seated Cable Rows',
    muscles: [_pUpperBack, _sLats, _sBiceps],
  ),
  GlobalExerciseSeed(
    key: 't_bar_rows',
    name: 'T-Bar Rows',
    muscles: [_pUpperBack, _sLats, _sBiceps, _sRearDelts],
    legacyNames: ['T-Bar Row'],
  ),
  GlobalExerciseSeed(
    key: 'chest_supported_rows',
    name: 'Chest-Supported Rows',
    muscles: [_pUpperBack, _sLats, _sRearDelts, _sBiceps],
    legacyNames: ['Chest-Supported Row'],
  ),
  GlobalExerciseSeed(
    key: 'machine_rows',
    name: 'Machine Rows',
    muscles: [_pUpperBack, _sLats, _sRearDelts, _sBiceps],
  ),
  GlobalExerciseSeed(
    key: 'inverted_rows',
    name: 'Inverted Rows',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pUpperBack, _sLats, _sBiceps, _sRearDelts],
  ),
  GlobalExerciseSeed(
    key: 'db_shrugs',
    name: 'DB Shrugs',
    muscles: [_pTraps, _sForearms],
  ),
  GlobalExerciseSeed(
    key: 'bb_shrugs',
    name: 'BB Shrugs',
    muscles: [_pTraps, _sForearms],
  ),
  GlobalExerciseSeed(
    key: 'smith_machine_shrugs',
    name: 'Smith Machine Shrugs',
    muscles: [_pTraps, _sForearms],
  ),
  GlobalExerciseSeed(
    key: 'cable_shrugs',
    name: 'Cable Shrugs',
    muscles: [_pTraps],
  ),
  GlobalExerciseSeed(
    key: 'deadlifts',
    name: 'Deadlifts',
    muscles: [_pErectors, _sGlutes, _sHamstrings, _sTraps, _sUpperBack, _sForearms],
    legacyNames: ['Deadlift'],
  ),
  GlobalExerciseSeed(
    key: 'sumo_deadlifts',
    name: 'Sumo Deadlifts',
    muscles: [_pGlutes, _sQuads, _sHamstrings, _sAdductors, _sErectors, _sTraps],
  ),
  GlobalExerciseSeed(
    key: 'back_extensions',
    name: 'Back Extensions',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pErectors, _sGlutes, _sHamstrings],
  ),
  GlobalExerciseSeed(
    key: 'weighted_back_extensions',
    name: 'Weighted Back Extensions',
    muscles: [_pErectors, _sGlutes, _sHamstrings],
  ),
  GlobalExerciseSeed(
    key: 'good_mornings',
    name: 'Good Mornings',
    muscles: [_pErectors, _sHamstrings, _sGlutes],
  ),

  // ── Shoulders — Front, Side & Rear Delts (20) ──────────────────────────────
  GlobalExerciseSeed(
    key: 'overhead_press',
    name: 'Overhead Press',
    muscles: [_pFrontDelts, _sSideDelts, _sTriceps],
  ),
  GlobalExerciseSeed(
    key: 'db_shoulder_press',
    name: 'DB Shoulder Press',
    muscles: [_pFrontDelts, _sSideDelts, _sTriceps],
    legacyNames: ['Dumbbell Shoulder Press'],
  ),
  GlobalExerciseSeed(
    key: 'neutral_grip_db_shoulder_press',
    name: 'Neutral-Grip DB Shoulder Press',
    muscles: [_pFrontDelts, _sSideDelts, _sTriceps],
  ),
  GlobalExerciseSeed(
    key: 'single_arm_db_shoulder_press',
    name: 'Single-Arm DB Shoulder Press',
    muscles: [_pFrontDelts, _sSideDelts, _sTriceps, _sObliques],
  ),
  GlobalExerciseSeed(
    key: 'single_arm_landmine_press',
    name: 'Single-Arm Landmine Press',
    muscles: [_pFrontDelts, _sChest, _sTriceps, _sObliques],
  ),
  GlobalExerciseSeed(
    key: 'smith_machine_shoulder_press',
    name: 'Smith Machine Shoulder Press',
    muscles: [_pFrontDelts, _sSideDelts, _sTriceps],
  ),
  GlobalExerciseSeed(
    key: 'machine_shoulder_press',
    name: 'Machine Shoulder Press',
    muscles: [_pFrontDelts, _sSideDelts, _sTriceps],
  ),
  GlobalExerciseSeed(
    key: 'arnold_press',
    name: 'Arnold Press',
    muscles: [_pFrontDelts, _sSideDelts, _sTriceps],
  ),
  GlobalExerciseSeed(
    key: 'db_front_raises',
    name: 'DB Front Raises',
    muscles: [_pFrontDelts],
    legacyNames: ['Front Raise'],
  ),
  GlobalExerciseSeed(
    key: 'cable_front_raises',
    name: 'Cable Front Raises',
    muscles: [_pFrontDelts],
  ),
  GlobalExerciseSeed(
    key: 'battle_ropes',
    name: 'Battle Ropes',
    mode: ExerciseTrackingMode.timed,
    muscles: [_pFrontDelts, _sSideDelts, _sForearms, _sAbs],
  ),
  GlobalExerciseSeed(
    key: 'db_lateral_raises',
    name: 'DB Lateral Raises',
    muscles: [_pSideDelts],
    legacyNames: ['Lateral Raises'],
  ),
  GlobalExerciseSeed(
    key: 'cable_lateral_raises',
    name: 'Cable Lateral Raises',
    muscles: [_pSideDelts],
  ),
  GlobalExerciseSeed(
    key: 'machine_lateral_raises',
    name: 'Machine Lateral Raises',
    muscles: [_pSideDelts],
  ),
  GlobalExerciseSeed(
    key: 'upright_rows',
    name: 'Upright Rows',
    muscles: [_pSideDelts, _sTraps],
    legacyNames: ['Upright Row'],
  ),
  GlobalExerciseSeed(
    key: 'wide_grip_upright_rows',
    name: 'Wide-Grip Upright Rows',
    muscles: [_pSideDelts, _sTraps],
  ),
  GlobalExerciseSeed(
    key: 'face_pulls',
    name: 'Face Pulls',
    muscles: [_pRearDelts, _sTraps, _sUpperBack],
  ),
  GlobalExerciseSeed(
    key: 'reverse_flys',
    name: 'Reverse Flys',
    muscles: [_pRearDelts, _sUpperBack],
    legacyNames: ['Reverse Fly'],
  ),
  GlobalExerciseSeed(
    key: 'reverse_pec_deck',
    name: 'Reverse Pec Deck',
    muscles: [_pRearDelts, _sUpperBack],
  ),
  GlobalExerciseSeed(
    key: 'cable_rear_delt_flys',
    name: 'Cable Rear Delt Flys',
    muscles: [_pRearDelts, _sUpperBack],
  ),

  // ── Arms — Triceps, Biceps & Forearms (27) ─────────────────────────────────
  GlobalExerciseSeed(
    key: 'tricep_pushdowns',
    name: 'Tricep Pushdowns',
    muscles: [_pTriceps],
    legacyNames: ['Tricep Pushdown'],
  ),
  GlobalExerciseSeed(
    key: 'skull_crushers',
    name: 'Skull Crushers',
    muscles: [_pTriceps],
  ),
  GlobalExerciseSeed(
    key: 'overhead_db_tricep_extensions',
    name: 'Overhead DB Tricep Extensions',
    muscles: [_pTriceps],
    legacyNames: ['Overhead Tricep Extension'],
  ),
  GlobalExerciseSeed(
    key: 'overhead_cable_tricep_extensions',
    name: 'Overhead Cable Tricep Extensions',
    muscles: [_pTriceps],
  ),
  GlobalExerciseSeed(
    key: 'close_grip_bench_press',
    name: 'Close-Grip Bench Press',
    muscles: [_pTriceps, _sChest, _sFrontDelts],
  ),
  GlobalExerciseSeed(
    key: 'smith_machine_close_grip_bench_press',
    name: 'Smith Machine Close-Grip Bench Press',
    muscles: [_pTriceps, _sChest, _sFrontDelts],
  ),
  GlobalExerciseSeed(
    key: 'jm_press',
    name: 'JM Press',
    muscles: [_pTriceps, _sChest, _sFrontDelts],
  ),
  GlobalExerciseSeed(
    key: 'db_tricep_kickbacks',
    name: 'DB Tricep Kickbacks',
    muscles: [_pTriceps],
    legacyNames: ['Tricep Kickback'],
  ),
  GlobalExerciseSeed(
    key: 'diamond_push_ups',
    name: 'Diamond Push-Ups',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pTriceps, _sChest, _sFrontDelts],
  ),
  GlobalExerciseSeed(
    key: 'bench_dips',
    name: 'Bench Dips',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pTriceps, _sChest, _sFrontDelts],
  ),
  GlobalExerciseSeed(
    key: 'bb_curls',
    name: 'BB Curls',
    muscles: [_pBiceps],
    legacyNames: ['Barbell Curl'],
  ),
  GlobalExerciseSeed(
    key: 'ez_bar_curls',
    name: 'EZ-Bar Curls',
    muscles: [_pBiceps],
  ),
  GlobalExerciseSeed(
    key: 'wide_grip_ez_bar_curls',
    name: 'Wide-Grip EZ-Bar Curls',
    muscles: [_pBiceps],
  ),
  GlobalExerciseSeed(
    key: 'close_grip_ez_bar_curls',
    name: 'Close-Grip EZ-Bar Curls',
    muscles: [_pBiceps],
  ),
  GlobalExerciseSeed(
    key: 'db_curls',
    name: 'DB Curls',
    muscles: [_pBiceps],
    legacyNames: ['Dumbbell Curl'],
  ),
  GlobalExerciseSeed(
    key: 'incline_db_curls',
    name: 'Incline DB Curls',
    muscles: [_pBiceps],
    legacyNames: ['Incline Dumbbell Curl'],
  ),
  GlobalExerciseSeed(
    key: 'hammer_curls',
    name: 'Hammer Curls',
    muscles: [_pBiceps, _sForearms],
    legacyNames: ['Hammer Curl'],
  ),
  GlobalExerciseSeed(
    key: 'preacher_curls',
    name: 'Preacher Curls',
    muscles: [_pBiceps],
    legacyNames: ['Preacher Curl'],
  ),
  GlobalExerciseSeed(
    key: 'cable_curls',
    name: 'Cable Curls',
    muscles: [_pBiceps],
    legacyNames: ['Cable Curl'],
  ),
  GlobalExerciseSeed(
    key: 'bayesian_cable_curls',
    name: 'Bayesian Cable Curls',
    muscles: [_pBiceps],
  ),
  GlobalExerciseSeed(
    key: 'spider_curls',
    name: 'Spider Curls',
    muscles: [_pBiceps],
  ),
  GlobalExerciseSeed(
    key: 'concentration_curls',
    name: 'Concentration Curls',
    muscles: [_pBiceps],
  ),
  GlobalExerciseSeed(
    key: 'reverse_curls',
    name: 'Reverse Curls',
    muscles: [_pForearms, _sBiceps],
  ),
  GlobalExerciseSeed(
    key: 'wrist_curls',
    name: 'Wrist Curls',
    muscles: [_pForearms],
  ),
  GlobalExerciseSeed(
    key: 'reverse_wrist_curls',
    name: 'Reverse Wrist Curls',
    muscles: [_pForearms],
  ),
  GlobalExerciseSeed(
    key: 'farmers_walk',
    name: "Farmer's Walk",
    mode: ExerciseTrackingMode.timed,
    muscles: [_pForearms, _sTraps, _sAbs],
  ),
  GlobalExerciseSeed(
    key: 'dead_hang',
    name: 'Dead Hang',
    mode: ExerciseTrackingMode.timed,
    muscles: [_pForearms, _sLats],
  ),

  // ── Legs (39) ──────────────────────────────────────────────────────────────
  GlobalExerciseSeed(
    key: 'back_squats',
    name: 'Back Squats',
    muscles: [_pQuads, _sGlutes, _sAdductors, _sErectors],
    legacyNames: ['Squat'],
  ),
  GlobalExerciseSeed(
    key: 'front_squats',
    name: 'Front Squats',
    muscles: [_pQuads, _sGlutes, _sUpperBack, _sErectors],
    legacyNames: ['Front Squat'],
  ),
  GlobalExerciseSeed(
    key: 'smith_machine_squats',
    name: 'Smith Machine Squats',
    muscles: [_pQuads, _sGlutes],
  ),
  GlobalExerciseSeed(
    key: 'hack_squats',
    name: 'Hack Squats',
    muscles: [_pQuads, _sGlutes],
    legacyNames: ['Hack Squat'],
  ),
  GlobalExerciseSeed(
    key: 'pendulum_squats',
    name: 'Pendulum Squats',
    muscles: [_pQuads, _sGlutes],
  ),
  GlobalExerciseSeed(
    key: 'leg_press',
    name: 'Leg Press',
    muscles: [_pQuads, _sGlutes],
  ),
  GlobalExerciseSeed(
    key: 'single_leg_press',
    name: 'Single-Leg Press',
    muscles: [_pQuads, _sGlutes],
  ),
  GlobalExerciseSeed(
    key: 'leg_extensions',
    name: 'Leg Extensions',
    muscles: [_pQuads],
    legacyNames: ['Leg Extension'],
  ),
  GlobalExerciseSeed(
    key: 'bulgarian_split_squats',
    name: 'Bulgarian Split Squats',
    muscles: [_pQuads, _sGlutes, _sAdductors],
    legacyNames: ['Bulgarian Split Squat'],
  ),
  GlobalExerciseSeed(
    key: 'smith_machine_bulgarian_split_squats',
    name: 'Smith Machine Bulgarian Split Squats',
    muscles: [_pQuads, _sGlutes, _sAdductors],
  ),
  GlobalExerciseSeed(
    key: 'goblet_squats',
    name: 'Goblet Squats',
    muscles: [_pQuads, _sGlutes, _sErectors],
    legacyNames: ['Goblet Squat'],
  ),
  GlobalExerciseSeed(
    key: 'lunges',
    name: 'Lunges',
    muscles: [_pQuads, _sGlutes, _sAdductors],
  ),
  GlobalExerciseSeed(
    key: 'walking_lunges',
    name: 'Walking Lunges',
    muscles: [_pQuads, _sGlutes, _sAdductors],
  ),
  GlobalExerciseSeed(
    key: 'step_ups',
    name: 'Step-Ups',
    muscles: [_pQuads, _sGlutes],
  ),
  GlobalExerciseSeed(
    key: 'sissy_squats',
    name: 'Sissy Squats',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pQuads],
  ),
  GlobalExerciseSeed(
    key: 'romanian_deadlifts',
    name: 'Romanian Deadlifts',
    muscles: [_pHamstrings, _sGlutes, _sErectors],
    legacyNames: ['Romanian Deadlift'],
  ),
  GlobalExerciseSeed(
    key: 'db_romanian_deadlifts',
    name: 'DB Romanian Deadlifts',
    muscles: [_pHamstrings, _sGlutes, _sErectors],
  ),
  GlobalExerciseSeed(
    key: 'smith_machine_romanian_deadlifts',
    name: 'Smith Machine Romanian Deadlifts',
    muscles: [_pHamstrings, _sGlutes, _sErectors],
  ),
  GlobalExerciseSeed(
    key: 'stiff_leg_deadlifts',
    name: 'Stiff-Leg Deadlifts',
    muscles: [_pHamstrings, _sGlutes, _sErectors],
    legacyNames: ['Stiff-Leg Deadlift'],
  ),
  GlobalExerciseSeed(
    key: 'seated_leg_curls',
    name: 'Seated Leg Curls',
    muscles: [_pHamstrings],
    legacyNames: ['Leg Curl'],
  ),
  GlobalExerciseSeed(
    key: 'lying_leg_curls',
    name: 'Lying Leg Curls',
    muscles: [_pHamstrings],
  ),
  GlobalExerciseSeed(
    key: 'nordic_curls',
    name: 'Nordic Curls',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pHamstrings],
    legacyNames: ['Nordic Curl'],
  ),
  GlobalExerciseSeed(
    key: 'glute_ham_raises',
    name: 'Glute-Ham Raises',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pHamstrings, _sGlutes, _sErectors],
  ),
  GlobalExerciseSeed(
    key: 'hip_thrusts',
    name: 'Hip Thrusts',
    muscles: [_pGlutes, _sHamstrings],
    legacyNames: ['Hip Thrust'],
  ),
  GlobalExerciseSeed(
    key: 'smith_machine_hip_thrusts',
    name: 'Smith Machine Hip Thrusts',
    muscles: [_pGlutes, _sHamstrings],
  ),
  GlobalExerciseSeed(
    key: 'single_leg_hip_thrusts',
    name: 'Single-Leg Hip Thrusts',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pGlutes, _sHamstrings],
  ),
  GlobalExerciseSeed(
    key: 'glute_bridges',
    name: 'Glute Bridges',
    muscles: [_pGlutes, _sHamstrings],
    legacyNames: ['Glute Bridge'],
  ),
  GlobalExerciseSeed(
    key: 'sumo_squats',
    name: 'Sumo Squats',
    muscles: [_pGlutes, _sQuads, _sAdductors],
    legacyNames: ['Sumo Squat'],
  ),
  GlobalExerciseSeed(
    key: 'cable_glute_kickbacks',
    name: 'Cable Glute Kickbacks',
    muscles: [_pGlutes],
    legacyNames: ['Cable Kickback'],
  ),
  GlobalExerciseSeed(
    key: 'hip_adductions',
    name: 'Hip Adductions',
    muscles: [_pAdductors],
  ),
  GlobalExerciseSeed(
    key: 'copenhagen_plank',
    name: 'Copenhagen Plank',
    mode: ExerciseTrackingMode.timed,
    muscles: [_pAdductors, _sObliques],
  ),
  GlobalExerciseSeed(
    key: 'hip_abductions',
    name: 'Hip Abductions',
    muscles: [_pAbductors, _sGlutes],
  ),
  GlobalExerciseSeed(
    key: 'cable_hip_abductions',
    name: 'Cable Hip Abductions',
    muscles: [_pAbductors, _sGlutes],
  ),
  GlobalExerciseSeed(
    key: 'cable_hip_flexions',
    name: 'Cable Hip Flexions',
    muscles: [_pHipFlexors],
  ),
  GlobalExerciseSeed(
    key: 'l_sit_hold',
    name: 'L-Sit Hold',
    mode: ExerciseTrackingMode.timed,
    muscles: [_pHipFlexors, _sAbs],
  ),
  GlobalExerciseSeed(
    key: 'standing_calf_raises',
    name: 'Standing Calf Raises',
    muscles: [_pCalves],
    legacyNames: ['Calf Raises'],
  ),
  GlobalExerciseSeed(
    key: 'smith_machine_calf_raises',
    name: 'Smith Machine Calf Raises',
    muscles: [_pCalves],
  ),
  GlobalExerciseSeed(
    key: 'seated_calf_raises',
    name: 'Seated Calf Raises',
    muscles: [_pCalves],
  ),
  GlobalExerciseSeed(
    key: 'leg_press_calf_raises',
    name: 'Leg Press Calf Raises',
    muscles: [_pCalves],
  ),

  // ── Core — Abs & Obliques (29) + Neck (2) ──────────────────────────────────
  GlobalExerciseSeed(
    key: 'crunches',
    name: 'Crunches',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pAbs],
  ),
  GlobalExerciseSeed(
    key: 'sit_ups',
    name: 'Sit-Ups',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pAbs, _sHipFlexors],
  ),
  GlobalExerciseSeed(
    key: 'decline_sit_ups',
    name: 'Decline Sit-Ups',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pAbs, _sHipFlexors],
    legacyNames: ['Decline Sit-up'],
  ),
  GlobalExerciseSeed(
    key: 'weighted_decline_sit_ups',
    name: 'Weighted Decline Sit-Ups',
    muscles: [_pAbs, _sHipFlexors],
  ),
  GlobalExerciseSeed(
    key: 'v_ups',
    name: 'V-Ups',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pAbs, _sHipFlexors],
  ),
  GlobalExerciseSeed(
    key: 'cable_crunches',
    name: 'Cable Crunches',
    muscles: [_pAbs],
    legacyNames: ['Cable Crunch'],
  ),
  GlobalExerciseSeed(
    key: 'machine_crunches',
    name: 'Machine Crunches',
    muscles: [_pAbs],
  ),
  GlobalExerciseSeed(
    key: 'reverse_crunches',
    name: 'Reverse Crunches',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pAbs],
  ),
  GlobalExerciseSeed(
    key: 'decline_reverse_crunches',
    name: 'Decline Reverse Crunches',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pAbs, _sHipFlexors],
  ),
  GlobalExerciseSeed(
    key: 'lying_leg_raises',
    name: 'Lying Leg Raises',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pAbs, _sHipFlexors],
  ),
  GlobalExerciseSeed(
    key: 'captains_chair_leg_raises',
    name: "Captain's Chair Leg Raises",
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pAbs, _sHipFlexors],
  ),
  GlobalExerciseSeed(
    key: 'hanging_knee_raises',
    name: 'Hanging Knee Raises',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pAbs, _sHipFlexors],
  ),
  GlobalExerciseSeed(
    key: 'hanging_leg_raises',
    name: 'Hanging Leg Raises',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pAbs, _sHipFlexors],
    legacyNames: ['Hanging Leg Raise'],
  ),
  GlobalExerciseSeed(
    key: 'toes_to_bar',
    name: 'Toes-To-Bar',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pAbs, _sHipFlexors, _sLats, _sForearms],
  ),
  GlobalExerciseSeed(
    key: 'dragon_flags',
    name: 'Dragon Flags',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pAbs, _sHipFlexors, _sObliques, _sLats],
  ),
  GlobalExerciseSeed(
    key: 'plank',
    name: 'Plank',
    mode: ExerciseTrackingMode.timed,
    muscles: [_pAbs, _sObliques],
  ),
  GlobalExerciseSeed(
    key: 'hollow_body_hold',
    name: 'Hollow Body Hold',
    mode: ExerciseTrackingMode.timed,
    muscles: [_pAbs, _sHipFlexors],
  ),
  GlobalExerciseSeed(
    key: 'kneeling_ab_wheel_rollouts',
    name: 'Kneeling Ab Wheel Rollouts',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pAbs, _sHipFlexors],
    legacyNames: ['Ab Wheel Rollout'],
  ),
  GlobalExerciseSeed(
    key: 'standing_ab_wheel_rollouts',
    name: 'Standing Ab Wheel Rollouts',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pAbs, _sHipFlexors, _sLats],
  ),
  GlobalExerciseSeed(
    key: 'dead_bugs',
    name: 'Dead Bugs',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pAbs, _sHipFlexors],
    legacyNames: ['Dead Bug'],
  ),
  GlobalExerciseSeed(
    key: 'mountain_climbers',
    name: 'Mountain Climbers',
    mode: ExerciseTrackingMode.timed,
    muscles: [_pAbs, _sHipFlexors, _sFrontDelts],
  ),
  GlobalExerciseSeed(
    key: 'side_plank',
    name: 'Side Plank',
    mode: ExerciseTrackingMode.timed,
    muscles: [_pObliques, _sAbs],
  ),
  GlobalExerciseSeed(
    key: 'bicycle_crunches',
    name: 'Bicycle Crunches',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pObliques, _sAbs, _sHipFlexors],
  ),
  GlobalExerciseSeed(
    key: 'russian_twists',
    name: 'Russian Twists',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pObliques, _sAbs],
    legacyNames: ['Russian Twist'],
  ),
  GlobalExerciseSeed(
    key: 'weighted_russian_twists',
    name: 'Weighted Russian Twists',
    muscles: [_pObliques, _sAbs],
  ),
  GlobalExerciseSeed(
    key: 'hanging_windshield_wipers',
    name: 'Hanging Windshield Wipers',
    mode: ExerciseTrackingMode.bodyweightReps,
    muscles: [_pObliques, _sAbs, _sHipFlexors, _sForearms],
  ),
  GlobalExerciseSeed(
    key: 'cable_woodchoppers',
    name: 'Cable Woodchoppers',
    muscles: [_pObliques, _sAbs],
  ),
  GlobalExerciseSeed(
    key: 'pallof_press',
    name: 'Pallof Press',
    muscles: [_pObliques, _sAbs],
  ),
  GlobalExerciseSeed(
    key: 'suitcase_carry',
    name: 'Suitcase Carry',
    mode: ExerciseTrackingMode.timed,
    muscles: [_pObliques, _sForearms, _sTraps],
  ),
  GlobalExerciseSeed(
    key: 'neck_curls',
    name: 'Neck Curls',
    muscles: [_pNeck],
  ),
  GlobalExerciseSeed(
    key: 'neck_extensions',
    name: 'Neck Extensions',
    muscles: [_pNeck, _sTraps],
  ),

  // ── Cardio / Conditioning (8 — All Timed, non-muscle category) ─────────────
  GlobalExerciseSeed(
    key: 'treadmill_run',
    name: 'Treadmill Run',
    mode: ExerciseTrackingMode.timed,
    isCardio: true,
  ),
  GlobalExerciseSeed(
    key: 'rowing_machine',
    name: 'Rowing Machine',
    mode: ExerciseTrackingMode.timed,
    isCardio: true,
  ),
  GlobalExerciseSeed(
    key: 'jump_rope',
    name: 'Jump Rope',
    mode: ExerciseTrackingMode.timed,
    isCardio: true,
  ),
  GlobalExerciseSeed(
    key: 'assault_bike',
    name: 'Assault Bike',
    mode: ExerciseTrackingMode.timed,
    isCardio: true,
  ),
  GlobalExerciseSeed(
    key: 'stairmaster',
    name: 'Stairmaster',
    mode: ExerciseTrackingMode.timed,
    isCardio: true,
  ),
  GlobalExerciseSeed(
    key: 'cycling',
    name: 'Cycling',
    mode: ExerciseTrackingMode.timed,
    isCardio: true,
  ),
  GlobalExerciseSeed(
    key: 'elliptical',
    name: 'Elliptical',
    mode: ExerciseTrackingMode.timed,
    isCardio: true,
  ),
  GlobalExerciseSeed(
    key: 'skierg',
    name: 'SkiErg',
    mode: ExerciseTrackingMode.timed,
    isCardio: true,
  ),
];

/// Case-insensitive legacy exercise name → canonical Global Catalog v1 name.
final Map<String, String> kLegacyExerciseNameAliases = {
  for (final seed in kGlobalExerciseCatalog)
    for (final legacy in seed.legacyNames) legacy.toLowerCase(): seed.name,
};

/// Default pre-linked symmetric variation cliques. Every pair inside each list
/// is linked in `exercise_variations` during [ExercisesDao.syncGlobalCatalogV1].
const List<List<String>> kDefaultExerciseVariationGroups = [
  // 1. Flat Horizontal Press
  [
    'Bench Press',
    'Wide-Grip Bench Press',
    'DB Bench Press',
    'Neutral-Grip DB Bench Press',
    'Smith Machine Bench Press',
    'Machine Chest Press',
    'Push-Ups',
    'Wide-Grip Push-Ups',
  ],
  // 2. Incline Press
  [
    'Incline Bench Press',
    'Incline DB Bench Press',
    'Smith Machine Incline Bench Press',
  ],
  // 3. Decline / Dip Press
  ['Decline Bench Press', 'Dips', 'Weighted Dips'],
  // 4. Chest Flys
  ['DB Flys', 'Cable Flys', 'Low-To-High Cable Flys', 'Pec Deck'],
  // 5. Pull-Up Variations
  [
    'Pull-Ups',
    'Wide-Grip Pull-Ups',
    'Neutral-Grip Pull-Ups',
    'Chin-Ups',
    'Weighted Pull-Ups',
    'Weighted Neutral-Grip Pull-Ups',
    'Weighted Chin-Ups',
  ],
  // 6. Pulldown Variations (+ cross-link with Pull-Ups & Chin-Ups)
  [
    'Pull-Ups',
    'Chin-Ups',
    'Lat Pulldowns',
    'Wide-Grip Lat Pulldowns',
    'Neutral-Grip Lat Pulldowns',
    'Close-Grip Lat Pulldowns',
    'Underhand Lat Pulldowns',
  ],
  // 7. Free-Weight / Smith Barbell Rows
  [
    'BB Rows',
    'Wide-Grip BB Rows',
    'Underhand BB Rows',
    'Pendlay Rows',
    'Smith Machine Rows',
    'T-Bar Rows',
  ],
  // 8. Cable / Machine / Supported Rows
  [
    'Seated Cable Rows',
    'Wide-Grip Seated Cable Rows',
    'Close-Grip Seated Cable Rows',
    'Chest-Supported Rows',
    'Machine Rows',
    'Inverted Rows',
  ],
  // 9. Unilateral Rows
  ['Single-Arm DB Rows', 'Single-Arm Cable Rows', 'Meadows Rows'],
  // 10. Lat Isolation
  ['Straight-Arm Pulldowns', 'DB Pullovers'],
  // 11. Shrugs
  ['DB Shrugs', 'BB Shrugs', 'Smith Machine Shrugs', 'Cable Shrugs'],
  // 12. Floor Deadlifts
  ['Deadlifts', 'Sumo Deadlifts'],
  // 13. Spinal Extension
  ['Back Extensions', 'Weighted Back Extensions', 'Good Mornings'],
  // 14. Bilateral Shoulder Press
  [
    'Overhead Press',
    'DB Shoulder Press',
    'Neutral-Grip DB Shoulder Press',
    'Smith Machine Shoulder Press',
    'Machine Shoulder Press',
    'Arnold Press',
  ],
  // 15. Unilateral / Landmine Shoulder Press
  [
    'Single-Arm DB Shoulder Press',
    'Single-Arm Landmine Press',
    'DB Shoulder Press',
  ],
  // 16. Front Raises
  ['DB Front Raises', 'Cable Front Raises'],
  // 17. Lateral Raises & Upright Rows
  ['DB Lateral Raises', 'Cable Lateral Raises', 'Machine Lateral Raises'],
  ['Upright Rows', 'Wide-Grip Upright Rows'],
  // 18. Rear Delts
  ['Face Pulls', 'Reverse Flys', 'Reverse Pec Deck', 'Cable Rear Delt Flys'],
  // 19. Tricep Pushdowns / Kickbacks
  ['Tricep Pushdowns', 'Skull Crushers', 'DB Tricep Kickbacks'],
  // 20. Overhead Triceps
  ['Overhead DB Tricep Extensions', 'Overhead Cable Tricep Extensions'],
  // 21. Compound Triceps
  [
    'Close-Grip Bench Press',
    'Smith Machine Close-Grip Bench Press',
    'JM Press',
    'Diamond Push-Ups',
    'Bench Dips',
  ],
  // 22. Standing Bicep Curls
  [
    'BB Curls',
    'EZ-Bar Curls',
    'Wide-Grip EZ-Bar Curls',
    'Close-Grip EZ-Bar Curls',
    'DB Curls',
    'Cable Curls',
  ],
  // 23. Lengthened & Shortened Curls
  ['Incline DB Curls', 'Bayesian Cable Curls'],
  ['Preacher Curls', 'Spider Curls', 'Concentration Curls'],
  // 24. Bilateral Squat / Leg Press
  [
    'Back Squats',
    'Front Squats',
    'Smith Machine Squats',
    'Hack Squats',
    'Pendulum Squats',
    'Leg Press',
    'Goblet Squats',
  ],
  // 25. Unilateral Squat / Lunge / Leg Press
  [
    'Bulgarian Split Squats',
    'Smith Machine Bulgarian Split Squats',
    'Single-Leg Press',
    'Lunges',
    'Walking Lunges',
    'Step-Ups',
  ],
  // 26. Hamstring Hinge
  [
    'Romanian Deadlifts',
    'DB Romanian Deadlifts',
    'Smith Machine Romanian Deadlifts',
    'Stiff-Leg Deadlifts',
  ],
  // 27. Hamstring Curls
  ['Seated Leg Curls', 'Lying Leg Curls', 'Nordic Curls', 'Glute-Ham Raises'],
  // 28. Glutes & Calves
  [
    'Hip Thrusts',
    'Smith Machine Hip Thrusts',
    'Glute Bridges',
    'Single-Leg Hip Thrusts',
  ],
  [
    'Standing Calf Raises',
    'Smith Machine Calf Raises',
    'Seated Calf Raises',
    'Leg Press Calf Raises',
  ],
  // 29. Spinal Flexion Abs
  [
    'Crunches',
    'Sit-Ups',
    'Decline Sit-Ups',
    'Weighted Decline Sit-Ups',
    'V-Ups',
    'Cable Crunches',
    'Machine Crunches',
  ],
  // 30. Lower Abs / Leg Raise Progression
  [
    'Reverse Crunches',
    'Decline Reverse Crunches',
    'Lying Leg Raises',
    "Captain's Chair Leg Raises",
    'Hanging Knee Raises',
    'Hanging Leg Raises',
    'Toes-To-Bar',
    'Dragon Flags',
  ],
  // 31. Ab Rollouts & Oblique Rotation
  [
    'Kneeling Ab Wheel Rollouts',
    'Standing Ab Wheel Rollouts',
    'Plank',
    'Hollow Body Hold',
  ],
  [
    'Russian Twists',
    'Weighted Russian Twists',
    'Bicycle Crunches',
    'Cable Woodchoppers',
  ],
];
