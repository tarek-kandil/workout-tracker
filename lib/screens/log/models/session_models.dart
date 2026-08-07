import '../../../models/wod_item.dart';

// ─── Local session data models ─────────────────────────────────────────────────

class SetData {
  double weightKg;
  int reps;
  int durationSeconds;
  double? rpe;
  SetData({required this.weightKg, required this.reps, this.durationSeconds = 0, this.rpe});
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
