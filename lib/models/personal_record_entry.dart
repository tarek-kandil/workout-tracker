class PersonalRecordEntry {
  final int exerciseId;
  final String exerciseName;
  final String exerciseCategory;
  final double maxWeightKg;
  final double estimatedOneRm; // Epley: weight × (1 + reps/30)

  const PersonalRecordEntry({
    required this.exerciseId,
    required this.exerciseName,
    required this.exerciseCategory,
    required this.maxWeightKg,
    required this.estimatedOneRm,
  });
}
