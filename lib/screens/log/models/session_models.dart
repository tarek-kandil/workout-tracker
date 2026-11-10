import '../../../database/app_database.dart' show WorkoutSet;
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

  SessionItem({
    required this.id,
    required this.wodItem,
    this.skipped = false,
    this.isAdHoc = false,
    this.originalExerciseId,
  }) : skippedSets = {};
}

/// One labelled "last time" log shown in the history panel.
class ExerciseHistory {
  final String name;
  final DateTime date;
  final List<WorkoutSet> sets;
  const ExerciseHistory({required this.name, required this.date, required this.sets});
}

enum CardState { active, completed, upcoming }
