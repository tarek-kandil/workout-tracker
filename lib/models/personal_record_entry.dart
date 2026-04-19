class PersonalRecordEntry {
  final int exerciseId;
  final String exerciseName;
  final String exerciseCategory;
  final bool isTimed;
  // Weighted exercises
  final double maxWeightKg;
  final double estimatedOneRm; // Epley: weight × (1 + reps/30)
  // Timed exercises
  final int? maxDurationSeconds;

  const PersonalRecordEntry({
    required this.exerciseId,
    required this.exerciseName,
    required this.exerciseCategory,
    required this.isTimed,
    required this.maxWeightKg,
    required this.estimatedOneRm,
    this.maxDurationSeconds,
  });
}
