import 'package:drift/drift.dart';
import '../database/app_database.dart';

// Exercise categories
const List<String> kExerciseCategories = [
  'Push',
  'Pull',
  'Legs',
  'Core',
  'Cardio',
  'Other',
];

// Default exercise library — seeded on first launch
final List<ExercisesCompanion> kDefaultExercises = [
  // Push
  _ex('Bench Press', 'Push'),
  _ex('Incline Bench Press', 'Push'),
  _ex('Overhead Press', 'Push'),
  _ex('Dumbbell Shoulder Press', 'Push'),
  _ex('Tricep Pushdown', 'Push'),
  _ex('Dips', 'Push'),
  _ex('Push-ups', 'Push'),
  _ex('Lateral Raises', 'Push'),
  // Pull
  _ex('Deadlift', 'Pull'),
  _ex('Barbell Row', 'Pull'),
  _ex('Pull-ups', 'Pull'),
  _ex('Lat Pulldown', 'Pull'),
  _ex('Seated Cable Row', 'Pull'),
  _ex('Barbell Curl', 'Pull'),
  _ex('Dumbbell Curl', 'Pull'),
  _ex('Face Pulls', 'Pull'),
  // Legs
  _ex('Squat', 'Legs'),
  _ex('Romanian Deadlift', 'Legs'),
  _ex('Leg Press', 'Legs'),
  _ex('Lunges', 'Legs'),
  _ex('Leg Curl', 'Legs'),
  _ex('Leg Extension', 'Legs'),
  _ex('Calf Raises', 'Legs'),
  // Core
  _ex('Plank', 'Core'),
  _ex('Ab Wheel Rollout', 'Core'),
  _ex('Cable Crunch', 'Core'),
];

ExercisesCompanion _ex(String name, String category) => ExercisesCompanion(
      name: Value(name),
      category: Value(category),
    );
