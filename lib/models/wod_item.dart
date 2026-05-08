import 'next_wod_result.dart';

/// A single item in a WOD — either a standalone exercise or a circuit.
sealed class WodItem {}

class StandaloneWodExercise extends WodItem {
  final WodExerciseEntry entry;
  /// Per-exercise rest override (null = use WOD template default).
  final int? restSeconds;
  StandaloneWodExercise({required this.entry, this.restSeconds});
}

class WodCircuit extends WodItem {
  final int groupId;
  final String? name;
  final int rounds;
  final int restBetweenExercisesSeconds;
  final int restBetweenRoundsSeconds;
  final List<WodExerciseEntry> exercises;
  WodCircuit({
    required this.groupId,
    this.name,
    required this.rounds,
    required this.restBetweenExercisesSeconds,
    required this.restBetweenRoundsSeconds,
    required this.exercises,
  });
}
