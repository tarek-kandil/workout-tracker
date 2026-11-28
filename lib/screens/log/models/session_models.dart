import '../../../database/app_database.dart' show WorkoutSet;
import '../../../models/exercise_tracking_mode.dart';
import '../../../models/wod_item.dart';

// ─── Local session data models ─────────────────────────────────────────────────

class SetData {
  double weightKg;
  int reps;
  int durationSeconds;
  /// Reps In Reserve — how many more reps could have been done (0 = failure).
  /// Replaces the old RPE field; lower is harder. Null = not recorded.
  double? rir;
  SetData({required this.weightKg, required this.reps, this.durationSeconds = 0, this.rir});
}

class SessionItem {
  final int id;
  WodItem wodItem;
  bool skipped;
  bool isAdHoc;
  /// Set when this item was swapped from another exercise (e.g. to a
  /// variation): the exercise it replaced, so its history can still be shown.
  int? originalExerciseId;
  final Set<int> skippedSets;
  /// Preserves partial set/round progress if this item is reordered out of the
  /// active slot before all of its sets are finished.
  int savedSetIdx;
  int savedCircuitExIdx;

  SessionItem({
    required this.id,
    required this.wodItem,
    this.skipped = false,
    this.isAdHoc = false,
    this.originalExerciseId,
    this.savedSetIdx = 0,
    this.savedCircuitExIdx = 0,
  }) : skippedSets = {};
}

/// One labelled "last time" log shown in the history panel.
class ExerciseHistory {
  final String name;
  final DateTime date;
  final List<WorkoutSet> sets;
  final ExerciseTrackingMode trackingMode;
  /// True when this entry is the most recently logged exercise across the
  /// slot's exercise + linked variations ("what you did last time").
  final bool isLastDone;
  /// True when this entry belongs to a variation/original rather than the
  /// exercise currently displayed on the card header.
  final bool isVariation;

  const ExerciseHistory({
    required this.name,
    required this.date,
    required this.sets,
    this.trackingMode = ExerciseTrackingMode.weightedReps,
    this.isLastDone = false,
    this.isVariation = false,
  });
}

enum CardState { active, completed, upcoming }
