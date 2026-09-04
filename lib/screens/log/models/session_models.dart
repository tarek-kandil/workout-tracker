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
  final Set<int> skippedSets;

  SessionItem({
    required this.id,
    required this.wodItem,
    this.skipped = false,
    this.isAdHoc = false,
  }) : skippedSets = {};
}

enum CardState { active, completed, upcoming }
