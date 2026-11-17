import '../database/app_database.dart';

/// Unified tracking mode for exercises, replacing the legacy `isTimed` boolean.
enum ExerciseTrackingMode {
  weightedReps('weighted_reps', 'Weight + Reps', 'Weighted'),
  bodyweightReps('bodyweight_reps', 'Bodyweight (Reps)', 'Bodyweight'),
  timed('timed', 'Timed (Duration)', 'Timed');

  final String dbValue;
  final String label;
  final String shortLabel;

  const ExerciseTrackingMode(this.dbValue, this.label, this.shortLabel);

  static ExerciseTrackingMode fromDb(
    String? raw, {
    bool isTimedFallback = false,
  }) {
    if (isTimedFallback && (raw == null || raw == weightedReps.dbValue)) {
      return timed;
    }
    for (final mode in values) {
      if (mode.dbValue == raw) return mode;
    }
    return isTimedFallback ? timed : weightedReps;
  }
}

extension ExerciseTrackingModeX on Exercise {
  ExerciseTrackingMode get mode =>
      ExerciseTrackingMode.fromDb(trackingMode, isTimedFallback: isTimed);

  bool get isWeightedReps => mode == ExerciseTrackingMode.weightedReps;
  bool get isBodyweightReps => mode == ExerciseTrackingMode.bodyweightReps;
  bool get isTimedMode => mode == ExerciseTrackingMode.timed;
}
