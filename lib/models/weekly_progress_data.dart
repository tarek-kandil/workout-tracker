class WeeklyProgressData {
  /// Tonnage (kg) for the current calendar week (Mon–Sun).
  final double tonnageKg;

  /// Tonnage for the previous calendar week.
  final double lastWeekTonnageKg;

  /// Tonnage for each of the last 8 calendar weeks, oldest first.
  /// Index 7 = current (possibly partial) week.
  final List<double> sparkline;

  /// Number of sessions logged this calendar week.
  final int sessionCount;

  /// Number of WODs planned per week from the active program.
  final int plannedSessions;

  /// Average RPE across all sets with non-null RPE this week.
  /// Null if no sets have RPE logged.
  final double? avgRpe;

  /// Average RPE from the previous calendar week. Null if no data.
  final double? lastWeekAvgRpe;

  /// Total set count this week (including timed sets).
  final int totalSets;

  /// Total set count last week.
  final int lastWeekTotalSets;

  /// Tonnage for Push-category exercises this week.
  final double pushTonnageKg;

  /// Tonnage for Pull-category exercises this week.
  final double pullTonnageKg;

  /// Tonnage for Legs-category exercises this week.
  final double legsTonnageKg;

  /// Push set count this week.
  final int pushSets;

  /// Pull set count this week.
  final int pullSets;

  /// Legs set count this week.
  final int legsSets;

  const WeeklyProgressData({
    required this.tonnageKg,
    required this.lastWeekTonnageKg,
    required this.sparkline,
    required this.sessionCount,
    required this.plannedSessions,
    required this.avgRpe,
    required this.lastWeekAvgRpe,
    required this.totalSets,
    required this.lastWeekTotalSets,
    required this.pushTonnageKg,
    required this.pullTonnageKg,
    required this.legsTonnageKg,
    required this.pushSets,
    required this.pullSets,
    required this.legsSets,
  });

  /// Percentage change in tonnage vs last week. Null if last week = 0.
  double? get tonnageDeltaPct {
    if (lastWeekTonnageKg == 0) return null;
    return (tonnageKg - lastWeekTonnageKg) / lastWeekTonnageKg * 100;
  }

  /// Max tonnage among Push/Pull/Legs — used to compute bar fill %.
  double get maxGroupTonnage =>
      [pushTonnageKg, pullTonnageKg, legsTonnageKg]
          .fold(0.0, (a, b) => a > b ? a : b);
}
