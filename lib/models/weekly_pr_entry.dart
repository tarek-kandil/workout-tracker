class WeeklyPREntry {
  final String exerciseName;
  final double weightKg;
  final int reps;

  const WeeklyPREntry({
    required this.exerciseName,
    required this.weightKg,
    required this.reps,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeeklyPREntry &&
          runtimeType == other.runtimeType &&
          exerciseName == other.exerciseName &&
          weightKg == other.weightKg &&
          reps == other.reps;

  @override
  int get hashCode => Object.hash(exerciseName, weightKg, reps);
}
