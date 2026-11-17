import 'exercise_tracking_mode.dart';

class PersonalRecordEntry {
  final int exerciseId;
  final String exerciseName;
  final String exerciseCategory;
  final bool isTimed;
  final ExerciseTrackingMode trackingMode;
  // Weighted exercises
  final double maxWeightKg;
  final double estimatedOneRm; // Epley: weight × (1 + reps/30)
  // Bodyweight exercises
  final int? maxReps;
  // Timed exercises
  final int? maxDurationSeconds;

  const PersonalRecordEntry({
    required this.exerciseId,
    required this.exerciseName,
    required this.exerciseCategory,
    required this.isTimed,
    ExerciseTrackingMode? trackingMode,
    required this.maxWeightKg,
    required this.estimatedOneRm,
    this.maxReps,
    this.maxDurationSeconds,
  }) : trackingMode = trackingMode ??
            (isTimed
                ? ExerciseTrackingMode.timed
                : ExerciseTrackingMode.weightedReps);

  bool get isBodyweightReps =>
      trackingMode == ExerciseTrackingMode.bodyweightReps;
  bool get isWeightedReps =>
      trackingMode == ExerciseTrackingMode.weightedReps;
}
