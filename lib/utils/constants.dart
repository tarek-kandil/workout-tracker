import 'package:drift/drift.dart';
import '../database/app_database.dart';

/// Ordered predefined muscle group list shown in the edit dialog chip grid.
const List<String> kMuscleGroups = [
  'Chest', 'Back', 'Shoulders', 'Triceps', 'Biceps',
  'Front Delt', 'Rear Delt', 'Quads', 'Hamstrings',
  'Glutes', 'Core', 'Calves', 'Full Body', 'Cardio',
];

/// exercise name → [primary muscle, ...secondary muscles]
const Map<String, List<String>> kExerciseMuscles = {
  // Chest
  'Bench Press':          ['Chest', 'Triceps', 'Front Delt'],
  'Incline Bench Press':  ['Chest', 'Triceps', 'Front Delt'],
  'Decline Bench Press':  ['Chest', 'Triceps'],
  'Dumbbell Fly':         ['Chest', 'Front Delt'],
  'Cable Fly':            ['Chest', 'Front Delt'],
  'Pec Deck':             ['Chest'],
  'Dips':                 ['Chest', 'Triceps', 'Front Delt'],
  'Push-ups':             ['Chest', 'Triceps', 'Front Delt'],
  // Back
  'Deadlift':                  ['Back', 'Glutes', 'Hamstrings', 'Core'],
  'Barbell Row':               ['Back', 'Biceps', 'Rear Delt'],
  'Pull-ups':                  ['Back', 'Biceps', 'Core'],
  'Lat Pulldown':              ['Back', 'Biceps'],
  'Seated Cable Row':          ['Back', 'Biceps', 'Rear Delt'],
  'T-Bar Row':                 ['Back', 'Biceps', 'Rear Delt'],
  'Single-Arm Dumbbell Row':   ['Back', 'Biceps'],
  'Chest-Supported Row':       ['Back', 'Rear Delt', 'Biceps'],
  'Straight-Arm Pulldown':     ['Back'],
  // Shoulders
  'Overhead Press':            ['Shoulders', 'Triceps', 'Front Delt'],
  'Dumbbell Shoulder Press':   ['Shoulders', 'Triceps', 'Front Delt'],
  'Arnold Press':              ['Shoulders', 'Triceps', 'Front Delt'],
  'Lateral Raises':            ['Shoulders'],
  'Upright Row':               ['Shoulders', 'Rear Delt', 'Biceps'],
  // Front Delt
  'Front Raise':    ['Front Delt', 'Shoulders'],
  // Rear Delt
  'Face Pulls':    ['Rear Delt', 'Shoulders'],
  'Reverse Fly':   ['Rear Delt', 'Shoulders'],
  // Triceps
  'Tricep Pushdown':           ['Triceps'],
  'Skull Crushers':            ['Triceps'],
  'Close-Grip Bench Press':    ['Triceps', 'Chest'],
  'Overhead Tricep Extension': ['Triceps'],
  'Tricep Kickback':           ['Triceps'],
  // Biceps
  'Barbell Curl':          ['Biceps'],
  'Dumbbell Curl':         ['Biceps'],
  'Hammer Curl':           ['Biceps'],
  'Preacher Curl':         ['Biceps'],
  'Cable Curl':            ['Biceps'],
  'Incline Dumbbell Curl': ['Biceps'],
  // Quads
  'Squat':                ['Quads', 'Glutes', 'Hamstrings', 'Core'],
  'Leg Press':            ['Quads', 'Glutes', 'Hamstrings'],
  'Leg Extension':        ['Quads'],
  'Lunges':               ['Quads', 'Glutes', 'Hamstrings'],
  'Hack Squat':           ['Quads', 'Glutes'],
  'Bulgarian Split Squat':['Quads', 'Glutes', 'Hamstrings'],
  'Goblet Squat':         ['Quads', 'Glutes', 'Core'],
  'Front Squat':          ['Quads', 'Glutes', 'Core'],
  // Hamstrings
  'Romanian Deadlift':  ['Hamstrings', 'Glutes', 'Back'],
  'Leg Curl':           ['Hamstrings'],
  'Nordic Curl':        ['Hamstrings', 'Glutes'],
  'Stiff-Leg Deadlift': ['Hamstrings', 'Glutes', 'Back'],
  // Glutes
  'Hip Thrust':    ['Glutes', 'Hamstrings'],
  'Glute Bridge':  ['Glutes', 'Hamstrings'],
  'Sumo Squat':    ['Glutes', 'Quads', 'Hamstrings'],
  'Cable Kickback':['Glutes'],
  // Calves
  'Calf Raises':        ['Calves'],
  'Seated Calf Raises': ['Calves'],
  // Core
  'Plank':             ['Core', 'Shoulders'],
  'Ab Wheel Rollout':  ['Core', 'Shoulders', 'Back'],
  'Cable Crunch':      ['Core'],
  'Hanging Leg Raise': ['Core'],
  'Russian Twist':     ['Core'],
  'Dead Bug':          ['Core'],
  'Side Plank':        ['Core', 'Shoulders'],
  'Decline Sit-up':    ['Core'],
  // Cardio
  'Treadmill Run':  ['Cardio'],
  'Rowing Machine': ['Cardio', 'Back'],
  'Jump Rope':      ['Cardio'],
  'Assault Bike':   ['Cardio'],
  'Stairmaster':    ['Cardio'],
  'Cycling':        ['Cardio'],
};

/// Full default exercise library (68 exercises). Inserted on first launch
/// and supplemented by the muscles_seeded_v1 pass.
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
